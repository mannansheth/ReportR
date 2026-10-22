const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const upload = require("../config/multerConfig")
const db = require('../config/dbConfig');
const { sendNotification } = require("./firebaseMessaging");
const { verifyIssue } = require('./IssueVerification');
const { uploadToCloudinary } = require("./UploadToCloudinary")
const { requireAuth } = require("./authMiddleware")
const { saveReportPdf, isPdf, validId } = require('./reportPdfStorage');
const community = require('./communityModel');

function generateOTP() {
  return require('crypto').randomInt(100000, 1000000).toString();
}

const getUserToken = async (id) => {
  try {
    const [rows] = await db.query("SELECT token FROM users WHERE id = ?", [id]);
    if (rows.length > 0) return rows[0].token;
    return null;
  } catch (err) {
    console.error(err);
  }
}

router.post('/sendNotification', requireAuth, async (req,res) => {
  const {Rid, name} = req.body;
  const token = await getUserToken(req.userId);
  if (token) {
    await sendNotification(token, "Your report is raised", `Report ${Rid} raised succesfully. Awaiting verification.`)
    return res.json({success:true})
  }
  res.json({success:false, message:"Token not found,"})
})

router.post(
  "/submitReport",
  requireAuth,
  upload.fields([
    { name: "image", maxCount: 1 },
    { name: "audio", maxCount: 1 },
    { name: "pdf", maxCount: 1 },
  ]),
  async (req, res) => {
    let dedupConnection;
    let reportCommitted = false;
    const uploadedAssets = [];
    const uploadAsset = async (...args) => { const asset=await uploadToCloudinary(...args);uploadedAssets.push(asset);return asset; };
    try {
      const {
        reportID,
        name,
        number,
        category,
        description,
        location,
        createdDate,
      } = req.body;
      const userID = req.userId;

      const imageFile = req.files?.image?.[0];
      const submittedPdf = req.files?.pdf?.[0];
      if (submittedPdf && !isPdf(submittedPdf.buffer)) return res.status(400).json({ success: false, message: 'The report document must be a valid PDF' });
      if (!imageFile) return res.status(400).json({ success: false, message: "Report image is required" });
      let parsedLocation;
      try { parsedLocation = typeof location === 'string' ? JSON.parse(location) : location; } catch (_) {}
      if (!reportID || !validId(reportID) || String(reportID).length > 20 || !category || !parsedLocation ||
          parsedLocation.lat == null || parsedLocation.lng == null ||
          !Number.isFinite(Number(parsedLocation.lat)) || !Number.isFinite(Number(parsedLocation.lng)) ||
          Math.abs(Number(parsedLocation.lat)) > 90 || Math.abs(Number(parsedLocation.lng)) > 180 ||
          String(category).length > 255 || String(description || "").length > 500) {
        return res.status(400).json({ success: false, message: 'Report ID, category, and valid location are required' });
      }
      const [existing] = await db.query('SELECT userID FROM reports WHERE Rid = ?', [reportID]);
      if (existing.length) {
        if (String(existing[0].userID) === String(userID) && submittedPdf) await saveReportPdf(reportID, submittedPdf.buffer);
        return String(existing[0].userID) === String(userID)
          ? res.json({ success: true, message: 'Report already submitted', data: { reportID } })
          : res.status(409).json({ success: false, message: 'Report ID already exists' });
      }
      await community.ensureSchema();
      dedupConnection = await db.getConnection();
      const [lock] = await dedupConnection.query("SELECT GET_LOCK('reportr:community-submit:v1', 20) AS acquired");
      if (!lock[0].acquired) return res.status(503).json({ success: false, message: 'Another report is being submitted. Please retry shortly.' });
      const [retry] = await dedupConnection.query('SELECT userID FROM reports WHERE Rid = ?', [reportID]);
      if (retry.length) return String(retry[0].userID) === String(userID)
        ? res.json({ success:true,message:'Report already submitted',data:{reportID} })
        : res.status(409).json({success:false,message:'Report ID already exists'});
      const matches = await community.nearbyMatches(category, parsedLocation, userID, dedupConnection);
      if (matches.length) return res.status(409).json({ success:false, code:'NEARBY_DUPLICATE', message:'This issue already has a nearby active report. Confirm the existing report instead.', report:matches[0] });
      const base64 = imageFile.buffer.toString("base64");
      let response;
      try { response = await verifyIssue(base64, imageFile.mimetype, category); }
      catch (error) {
        console.error('Automatic verification unavailable; queuing manual review:', error.message);
        response = { score: null, priority: null };
      }
      const status = response.score === null ? "Verification pending" : response.score > 60 ? "Issue Raised" : response.score > 5 ? "Verification pending" : "Invalid Report"
      let imageURL = null,
        audioURL = null,
        pdfURL = null;

      imageURL = (
        await uploadAsset(
          imageFile.buffer,
          `${reportID}_image`,
          imageFile.mimetype.startsWith("image/") ? "image" : "auto",
          reportID
        )
      ).secure_url;

      if (req.files?.audio) {
        const audioFile = req.files.audio[0];
        audioURL = (
          await uploadAsset(
            audioFile.buffer,
            `${reportID}_audio`,
            "audio",
            reportID
          )
        ).secure_url;
      }

      if (req.files?.pdf) {
        const pdfFile = req.files.pdf[0];
        pdfURL = (
          await uploadAsset(
            pdfFile.buffer,
            `${reportID}_pdf`,
            "pdf",
            reportID
          )
        ).secure_url;
      }

      const query = `
        INSERT INTO reports
        (Rid, priority, userID, issue, description, location, createdAt, imageURL, audioURL, pdfURL, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;

      const connection = dedupConnection;
      try {
      await connection.beginTransaction();
      await connection.query(query, [
        reportID,
        community.baselinePriority(category, description, response.priority),
        userID,
        category,
        description,
        location,
        new Date(),
        imageURL,
        audioURL,
        pdfURL,
        status
      ]);
      await connection.query(`INSERT INTO report_status_history (Rid, previousStatus, newStatus, actorUserID, source) VALUES (?, ?, ?, ?, ?)`, [reportID, null, status, userID, "system"]);
      await connection.query('INSERT INTO report_community (Rid,categoryKey,baselinePriority) VALUES (?,?,?)',[reportID,community.categoryKeys(category).join(','),community.baselinePriority(category,description,response.priority)]);
      await connection.commit();
      reportCommitted = true;
      } catch (error) {
        await connection.rollback();
        throw error;
      } finally { /* advisory lock remains held through commit */ }
      await dedupConnection.query("SELECT RELEASE_LOCK('reportr:community-submit:v1')");
      dedupConnection.release();
      dedupConnection = null;
      if (submittedPdf) await saveReportPdf(reportID, submittedPdf.buffer);
      const token = await getUserToken(userID);
      if (status === "Issue Raised") {
        if (token) await sendNotification(token, "Your report has been verified.", `Report ${reportID} has been verified successfully.`).catch(error => console.error("Report notification failed:", error.code))
      } else if (status === "Invalid Report") {
        if (token) await sendNotification(token, "Your report is invalid.", `Report ${reportID} did not show the mentioned issue. Please resubmit with a clearer photo.`).catch(error => console.error("Report notification failed:", error.code))
      }
      res.json({
        success: true,
        message: "Report submitted successfully",
        data: {
          reportID,
          userID,
          name,
          number,
          category,
          description,
          location,
          createdDate,
          imageURL,
          audioURL,
          pdfURL,
          status,
        },
      });
    } catch (err) {
      if (!reportCommitted) {
        const cloudinary = require('../config/cloudinaryConfig');
        await Promise.allSettled(uploadedAssets.filter(asset=>asset.public_id).map(asset=>cloudinary.uploader.destroy(asset.public_id,{resource_type:asset.resource_type || 'image',type:asset.type || 'upload'})));
      }
      console.error("Error submitting report:", err.code || err.message);
      res.status(502).json({ success: false, message: "Report upload could not be completed. Check your connection and retry." });
    } finally {
      if (dedupConnection) {
        await dedupConnection.query("SELECT RELEASE_LOCK('reportr:community-submit:v1')").catch(() => {});
        dedupConnection.release();
      }
    }
  }
);

const otpRequests = new Map();
const otpAttempts = new Map();
router.post('/sendOTP', async (req, res) => {
  const { phone, token } = req.body;
  if (!/^\d{10}$/.test(String(phone || '')) || typeof token !== 'string' || !token.trim()) {
    return res.status(400).json({ success: false, message: 'A valid 10 digit phone number and push token are required' });
  }
  const last = otpRequests.get(phone);
  if (last && Date.now() - last < 30000) return res.status(429).json({ success: false, message: 'Wait 30 seconds before requesting another OTP' });
  if (otpRequests.size > 10000) otpRequests.clear();
  otpRequests.set(phone, Date.now());
  otpAttempts.delete(phone);
  const otp = generateOTP();
  try {
    await db.execute('DELETE FROM otps WHERE phone = ?', [phone]);
    await db.execute('INSERT INTO otps (phone, otp, expiresAt) VALUES (?, ?, ?)', [phone, otp, new Date(Date.now() + 300000)]);
    await sendNotification(token, 'OTP for ReportR', `Your OTP is ${otp}`);
    res.json({ success: true, message: 'OTP sent to your device notification', expiresIn: 300 });
  } catch (err) {
    await db.execute('DELETE FROM otps WHERE phone = ? AND otp = ?', [phone, otp]).catch(() => {});
    otpRequests.delete(phone);
    console.error('OTP delivery failed:', err.code || err.message);
    res.status(502).json({ success: false, message: 'Unable to deliver the OTP notification. Check notification permissions and try again.' });
  }
});

router.post('/verifyOTP', async (req, res) => {
  const { phone, otp, name, token } = req.body;
  if (!/^\d{10}$/.test(String(phone || "")) || !/^\d{6}$/.test(String(otp || "")) || !name || String(name).trim().length < 2 || String(name).length > 100) {
    return res.status(400).json({ success: false, message: 'Phone, OTP, and name are required' });
  }
  if (!process.env.JWT_SECRET) {
    return res.status(503).json({ success: false, message: 'Authentication is not configured' });
  }

  if ((otpAttempts.get(phone) || 0) >= 5) return res.status(429).json({ success: false, message: 'Too many incorrect attempts. Request a new OTP.' });
  try {
    const [rows] = await db.execute(
      `SELECT * FROM otps WHERE phone = ? AND otp = ? AND expiresAt > NOW() ORDER BY id DESC LIMIT 1`,
      [phone, otp]
    );

    if (rows.length === 0) {
      otpAttempts.set(phone, (otpAttempts.get(phone) || 0) + 1);
      return res.status(400).json({ success: false, message: 'Invalid or expired OTP' });
    }

    const [consumed] = await db.execute('DELETE FROM otps WHERE id = ? AND expiresAt > NOW()', [rows[0].id]);
    if (consumed.affectedRows !== 1) return res.status(400).json({ success: false, message: 'OTP has already been used. Request a new OTP.' });
    const [existingUsers] = await db.execute(
      `SELECT id, name, number, role FROM users WHERE number = ? LIMIT 1`,
      [phone]
    );
    let user;
    if (existingUsers.length > 0) {
      user = existingUsers[0];
      await db.execute(`UPDATE users SET name = ?, token = ? WHERE id = ?`, [String(name).trim(), token || "", user.id]);
      user = { ...user, name, number: phone };
    } else {
      const [result] = await db.execute(
        `INSERT INTO users (name, number, createdAt, token, role) VALUES (?, ?, ?, ?, 'Citizen')`,
        [String(name).trim(), phone, new Date(), token || ""]
      );
      user = { id: result.insertId, name, number: phone, role: "Citizen" };
    }

    otpAttempts.delete(phone);
    const authToken = jwt.sign(
      { userId: String(user.id), role: user.role || "Citizen" },
      process.env.JWT_SECRET,
      { expiresIn: "30d" },
    );

    res.json({
      success: true,
      user: { id: user.id, name: user.name, phone: user.number, role: user.role || "Citizen" },
      authToken,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: 'Failed to verify OTP' });
  }
});

router.post("/getUserName", requireAuth, async (req, res) => {
  const id = req.userId;
  try {
    const [rows] = await db.query("SELECT name, number FROM users WHERE id = ?", [id]);
    if (rows.length > 0) return res.json({ name: rows[0].name, number: rows[0].number });
    res.json({ name: "", number: "" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ name: "" });
  }
});

router.post('/updateProfile', requireAuth, async (req, res) => {
  const name = String(req.body.name || '').trim();
  if (name.length < 2 || name.length > 100) return res.status(400).json({ success: false, message: 'Name must be between 2 and 100 characters' });
  try {
    await db.execute('UPDATE users SET name = ? WHERE id = ?', [name, req.userId]);
    const [rows] = await db.execute('SELECT id, name, number AS phone, role FROM users WHERE id = ?', [req.userId]);
    res.json({ success: true, user: rows[0] });
  } catch (err) {
    res.status(503).json({ success: false, message: 'Unable to update your profile. Try again.' });
  }
});
router.get('/profile', requireAuth, async (req, res) => {
  const [rows] = await db.execute('SELECT id, name, number AS phone, role FROM users WHERE id = ?', [req.userId]);
  res.json({ success: true, user: rows[0] });
});
module.exports = router;
