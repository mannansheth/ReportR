// Tests real blocked Cloudinary originals and private server delivery without
// printing credentials, bearer tokens, signed URLs, or personal report data.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const jwt = require('jsonwebtoken');
const db = require('../config/dbConfig');
const { readReportPdf, recoverReportPdf, saveReportPdf, originalDownloadUrl, isPdf } = require('../services/reportPdfStorage');
const app = require('../server');

(async () => {
  const [reports] = await db.query('SELECT r.Rid, r.userID, r.pdfURL FROM reports r JOIN users u ON u.id = r.userID WHERE r.pdfURL IS NOT NULL LIMIT 1');
  assert(reports.length, 'A real report PDF is required for the delivery test');
  const report = reports[0];
  assert.equal(originalDownloadUrl(report.Rid, 'https://localhost/private.pdf'), null);
  assert.equal(originalDownloadUrl('../escape', report.pdfURL), null);
  const recovered = await recoverReportPdf(report.Rid, report.pdfURL);
  assert(isPdf(recovered), 'Recovered Cloudinary original must be a real PDF');
  assert.deepEqual(await readReportPdf(report.Rid), recovered);
  const fixture = 'pdf-storage-check';
  const valid = Buffer.from('%PDF-1.7\nprivate fixture\n%%EOF');
  await saveReportPdf(fixture, valid);
  assert.deepEqual(await readReportPdf(fixture), valid);
  await assert.rejects(saveReportPdf(fixture, Buffer.from('not a PDF')));
  await fs.rm(path.resolve(__dirname, `../data/reports/${fixture}.pdf`));
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const token = id => jwt.sign({ userId: String(id) }, process.env.JWT_SECRET, { expiresIn: '5m' });
  try {
    const endpoint = `${base}/api/reports/${encodeURIComponent(report.Rid)}/pdf`;
    assert.equal((await fetch(endpoint)).status, 401);
    const owner = await fetch(endpoint, { headers: { Authorization: `Bearer ${token(report.userID)}` } });
    assert.equal(owner.status, 200);
    assert.equal(owner.headers.get('content-type'), 'application/pdf');
    assert.equal(owner.headers.get('cache-control'), 'private, no-store');
    assert(isPdf(Buffer.from(await owner.arrayBuffer())));
    const [others] = await db.query("SELECT id FROM users WHERE id != ? AND role = 'Citizen' LIMIT 1", [report.userID]);
    if (others.length) assert.equal((await fetch(endpoint, { headers: { Authorization: `Bearer ${token(others[0].id)}` } })).status, 404);
    const [authorities] = await db.query("SELECT id FROM users WHERE role IN ('Authority', 'Admin') LIMIT 1");
    if (authorities.length) assert.equal((await fetch(endpoint, { headers: { Authorization: `Bearer ${token(authorities[0].id)}` } })).status, 200);
    console.log('Report PDF checks passed: signed original recovery, valid private archive, owner access, unauthorized denial, document headers.');
  } finally {
    await new Promise(resolve => server.close(resolve));
    await db.end();
  }
})().catch(async error => {
  console.error('Report PDF checks failed:', error.code || error.name, error.message?.replace(/https?:\/\/\S+/g, '[URL]'));
  await db.end().catch(() => {});
  process.exitCode = 1;
});
