const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');

// A complete one-page PDF with accurate cross-reference offsets. Attachment
// validation should reject arbitrary bytes before any external upload occurs.
function createPdfFixture() {
  const stream = 'BT /F1 12 Tf 40 80 Td (Integration report fixture) Tj ET';
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 120] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    `<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}\nendstream`,
  ];
  let document = '%PDF-1.4\n';
  const offsets = [0];
  objects.forEach((object, index) => {
    offsets.push(Buffer.byteLength(document));
    document += `${index + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xref = Buffer.byteLength(document);
  document += `xref\n0 ${offsets.length}\n0000000000 65535 f \n`;
  document += offsets.slice(1).map(offset => `${String(offset).padStart(10, '0')} 00000 n \n`).join('');
  document += `trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(document);
}
const pdfFixture = createPdfFixture();
// External services are isolated; HTTP handlers and MySQL remain real.
let uploadFails = false;
let aiFails = false;
let notificationFails = false;
let uploadCalls = 0;
function stub(modulePath, exports) {
  const id = require.resolve(modulePath);
  require.cache[id] = { id, filename: id, loaded: true, exports };
}
stub('../services/IssueVerification', { verifyIssue: async () => {
  if (aiFails) throw new Error('Integration AI outage');
  return { score: 95, priority: 6 };
} });
stub('../services/UploadToCloudinary', { uploadToCloudinary: async (_buffer, filename) => {
  uploadCalls++;
  if (uploadFails) throw new Error('Integration upload outage');
  return { secure_url: `https://example.invalid/test/${filename}` };
} });
stub('../services/firebaseMessaging', { sendNotification: async () => {
  if (notificationFails) throw Object.assign(new Error('Integration FCM rejection'), {code: 'TEST_FCM_FAILURE'});
  return true;
} });
const app = require('../server');
const db = require('../config/dbConfig');
const jwt = require('jsonwebtoken');
(async () => {
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  let userId;
  let authorityId;
  let outsiderId;
  const reportId = `IT${Date.now()}`;
  const reviewId = `IR${Date.now()}`;
  const request = async (path, body, token) => {
    const res = await fetch(base + path, { method: body === undefined ? 'GET' : 'POST', headers: { 'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {}) }, ...(body === undefined ? {} : {body: JSON.stringify(body)}) });
    return { status: res.status, data: await res.json() };
  };
  try {
    assert.equal((await request('/')).data.Hello, 'Working');
    assert.equal((await request('/api/user/sendOTP', {})).status, 400);
    assert.equal((await request('/api/reports/getUserReports', {})).status, 401);
    const [insert] = await db.execute("INSERT INTO users (name, number, createdAt, token, role) VALUES (?, ?, NOW(), '', 'Citizen')", ['Integration fixture', '9999999900']);
    userId = insert.insertId;
    const token = jwt.sign({userId: String(userId)}, process.env.JWT_SECRET);
    assert.equal((await request('/api/reports/getUserReports', {}, token)).status, 200);
    assert.deepEqual((await request('/api/reports/getUserReports', {}, token)).data, []);
    assert.equal((await request('/api/reports/getAuthorityReports', {}, token)).status, 403);
    assert.equal((await request('/api/user/updateProfile', {name: 'Updated fixture'}, token)).data.user.name, 'Updated fixture');
    assert.equal((await request('/api/reports/getReportData', {Rid: 'not-existing'}, token)).status, 404);
    assert.equal((await request('/api/user/verifyOTP', {phone:'9999999900',otp:'000000',name:'Fixture'})).status, 400);
    await db.execute('INSERT INTO otps (phone, otp, expiresAt) VALUES (?, ?, ?)', ['9999999900', '123456', new Date(Date.now() + 60000)]);
    const authenticated = await request('/api/user/verifyOTP', {phone:'9999999900',otp:'123456',name:'Verified fixture',token:''});
    assert.equal(authenticated.status, 200);
    assert.equal(authenticated.data.success, true);
    assert.equal(String(authenticated.data.user.id), String(userId));
    assert.ok(authenticated.data.authToken);
    assert.equal((await request('/api/user/verifyOTP', {phone:'9999999900',otp:'123456',name:'Fixture'})).status, 400);
    const markers = (await request('/api/reports/getAllReports', undefined, token)).data;
    assert.ok(Array.isArray(markers));
    assert.ok(markers.every(item => item.lat != null && item.lng != null));
    const [reports] = await db.query('SELECT r.Rid, r.userID FROM reports r JOIN users u ON u.id = r.userID LIMIT 1');
    if (reports.length) {
      const ownerToken = jwt.sign({userId: String(reports[0].userID)}, process.env.JWT_SECRET);
      const report = await request('/api/reports/getReportData', {Rid:reports[0].Rid}, ownerToken);
      assert.equal(report.status, 200);
      assert.ok(!Number.isNaN(Date.parse(report.data.createdAt)));
      assert.equal((await request('/api/reports/getReportData', {Rid:reports[0].Rid}, token)).status, 404);
    }
    const [authority] = await db.execute("INSERT INTO users (name, number, createdAt, token, role) VALUES (?, ?, NOW(), '', 'Authority')", ['Authority fixture', '9999999901']);
    authorityId = authority.insertId;
    const authorityToken = jwt.sign({userId: String(authorityId)}, process.env.JWT_SECRET);
    const [outsider] = await db.execute("INSERT INTO users (name, number, createdAt, token, role) VALUES (?, ?, NOW(), '', 'Citizen')", ['Other citizen fixture', '9999999902']);
    outsiderId = outsider.insertId;
    const outsiderToken = jwt.sign({userId: String(outsiderId)}, process.env.JWT_SECRET);
    const upload = async (id, authToken = token, pdfBytes = pdfFixture) => {
      const form = new FormData();
      for (const [key, value] of Object.entries({reportID:id,category:'Pothole',description:'Integration fixture',location:JSON.stringify({lat:19.1,lng:72.9}),createdDate:new Date().toISOString()})) form.set(key, value);
      form.set('image', new Blob(['test-image'], {type:'image/jpeg'}), 'fixture.jpg');
      form.set('pdf', new Blob([pdfBytes], {type:'application/pdf'}), 'fixture.pdf');
      const response = await fetch(base + '/api/user/submitReport', {method:'POST',headers:{Authorization:`Bearer ${authToken}`},body:form});
      return {status:response.status,data:await response.json()};
    };
    assert.equal((await upload(reportId, token, Buffer.from('not a PDF'))).status, 400);
    assert.equal(uploadCalls, 0);
    uploadFails = true;
    assert.equal((await upload(reportId)).status, 502);
    assert.equal((await db.query('SELECT COUNT(*) count FROM reports WHERE Rid = ?', [reportId]))[0][0].count, 0);
    uploadFails = false;
    notificationFails = true;
    await db.execute('UPDATE users SET token = ? WHERE id = ?', ['integration-token', userId]);
    assert.equal((await upload(reportId)).data.success, true); // Notification failure cannot lose saved report.
    const pdfEndpoint = `${base}/api/reports/${reportId}/pdf`;
    assert.equal((await fetch(pdfEndpoint)).status, 401);
    assert.equal((await fetch(pdfEndpoint, {headers: {Authorization: `Bearer ${outsiderToken}`}})).status, 404);
    const deliveredPdf = await fetch(pdfEndpoint, {headers: {Authorization: `Bearer ${token}`}});
    assert.equal(deliveredPdf.status, 200);
    assert.equal(deliveredPdf.headers.get('content-type'), 'application/pdf');
    assert.equal(deliveredPdf.headers.get('cache-control'), 'private, no-store');
    assert.deepEqual(Buffer.from(await deliveredPdf.arrayBuffer()), pdfFixture);
    const authorityPdf = await fetch(pdfEndpoint, {headers: {Authorization: `Bearer ${authorityToken}`}});
    assert.equal(authorityPdf.status, 200);
    assert.deepEqual(Buffer.from(await authorityPdf.arrayBuffer()), pdfFixture);
    notificationFails = false;
    const beforeRetry = uploadCalls;
    assert.equal((await upload(reportId)).data.success, true);
    assert.equal(uploadCalls, beforeRetry);
    assert.equal((await db.query('SELECT COUNT(*) count FROM reports WHERE Rid = ?', [reportId]))[0][0].count, 1);
    assert.equal((await upload(reportId, authorityToken)).status, 409);
    assert.equal((await request('/api/reports/getReportData', {Rid:reportId}, authorityToken)).status, 404);
    const publicReport = await request('/api/reports/getPublicReportData', {Rid:reportId}, token);
    assert.equal(publicReport.data.userID, undefined);
    assert.equal(publicReport.data.audioURL, undefined);
    assert.equal((await request('/api/reports/getReportStatusHistory', {Rid:reportId}, token)).data.length, 1);
    assert.equal((await request('/api/reports/updateReportStatus', {Rid:reportId,status:'Resolved',resolutionNote:'Test'}, authorityToken)).status, 409);
    for (const status of ['Verification pending','In Progress','Resolved']) {
      const updated = await request('/api/reports/updateReportStatus', {Rid:reportId,status,resolutionNote:status === 'Resolved' ? 'Fixture resolved' : null}, authorityToken);
      assert.equal(updated.status, 200);
      assert.equal(updated.data.report.status, status);
    }
    const history = (await request('/api/reports/getReportStatusHistory', {Rid:reportId}, token)).data;
    assert.deepEqual(history.map(item => item.newStatus), ['Issue Raised','Verification pending','In Progress','Resolved']);
    aiFails = true;
    assert.equal((await upload(reviewId)).data.data.status, 'Verification pending');
    aiFails = false;
    const own = (await request('/api/reports/getUserReports', {}, token)).data;
    assert.equal(own.length, 2);
    assert.equal(own.filter(report => report.status === 'Resolved').length, 1);
    notificationFails = true;
    assert.equal((await request('/api/user/sendOTP', {phone:'9999999900',token:'bad-test-token'})).status, 502);
    assert.equal((await db.query('SELECT COUNT(*) count FROM otps WHERE phone = ?', ['9999999900']))[0][0].count, 0);
    notificationFails = false;
    await db.execute('INSERT INTO otps (phone, otp, expiresAt) VALUES (?, ?, ?)', ['9999999900','123456',new Date(Date.now() - 60000)]);
    assert.equal((await request('/api/user/verifyOTP', {phone:'9999999900',otp:'123456',name:'Fixture'})).status, 400);
    console.log('PASS: upload failure/retry/idempotency, PDF validation/private archive/owner and authority delivery/privacy, AI fallback, notification rejection, status lifecycle/history and real report statistics');
    console.log('PASS: health, OTP validation/verification/replay, auth, report list/detail/ownership/date, markers, authority access and profile persistence');
  } finally {
    for (const table of ['report_resolution_votes','report_confirmations','report_community']) await db.query(`DELETE FROM ${table} WHERE Rid IN (?, ?)`, [reportId,reviewId]);
    await db.execute('DELETE FROM report_status_history WHERE Rid IN (?, ?)', [reportId, reviewId]);
    await db.execute('DELETE FROM reports WHERE Rid IN (?, ?)', [reportId, reviewId]);
    await db.execute('DELETE FROM otps WHERE phone = ?', ['9999999900']);
    if (userId) await db.execute('DELETE FROM users WHERE id = ?', [userId]);
    if (authorityId) await db.execute('DELETE FROM users WHERE id = ?', [authorityId]);
    if (outsiderId) await db.execute('DELETE FROM users WHERE id = ?', [outsiderId]);
    await Promise.all([reportId, reviewId].map(id => fs.rm(path.resolve(__dirname, `../data/reports/${id}.pdf`), {force: true})));
    server.close();
    await db.end();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
