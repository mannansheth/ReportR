const express = require("express");
const router = express.Router();
const db = require("../config/dbConfig")
const { requireAuth, requireAuthority } = require("./authMiddleware")
const { sendNotification } = require("./firebaseMessaging")
const { readReportPdf, recoverReportPdf, validId } = require('./reportPdfStorage');
const community = require('./communityModel');

router.get('/:reportId/pdf', requireAuth, async (req, res) => {
  const id = req.params.reportId;
  if (!validId(id)) return res.status(400).json({ success: false, message: 'Invalid report ID' });
  try {
    const [rows] = await db.query('SELECT userID, pdfURL FROM reports WHERE Rid = ?', [id]);
    const report = rows[0];
    const authority = req.userRole === 'Authority' || req.userRole === 'Admin';
    if (!report || (!authority && String(report.userID) !== req.userId)) return res.status(404).json({ success: false, message: 'Report document not found' });
    const bytes = await readReportPdf(id) || await recoverReportPdf(id, report.pdfURL);
    if (!bytes) return res.status(404).json({ success: false, message: 'This report PDF is unavailable. A local copy may still be available on the phone where it was created.' });
    res.set({ 'Content-Type': 'application/pdf', 'Content-Disposition': `inline; filename="${id}.pdf"`, 'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff' });
    res.send(bytes);
  } catch (error) {
    console.error('Report PDF recovery failed:', error.code || error.name);
    res.status(502).json({ success: false, message: 'Unable to retrieve the report PDF. Please retry.' });
  }
});
router.get('/:reportId/audio', requireAuth, async (req,res) => {
  const id=req.params.reportId;
  if(!validId(id))return res.status(400).json({success:false,message:'Invalid report ID'});
  try{
    const [rows]=await db.query('SELECT userID,audioURL FROM reports WHERE Rid = ?',[id]);
    const report=rows[0],authority=['Authority','Admin'].includes(req.userRole);
    if(!report||(!authority&&String(report.userID)!==req.userId)||!report.audioURL)return res.status(404).json({success:false,message:'Report recording not found'});
    const media=require('./privateMedia'),asset=media.parseAsset(id,report.audioURL,'audio');
    const bytes=asset&&await media.downloadOriginal(id,report.audioURL,'audio');
    if(!bytes)return res.status(404).json({success:false,message:'Report recording is unavailable'});
    res.set({'Content-Type':media.audioMime(asset.extension),'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff','Accept-Ranges':'bytes','Content-Disposition':`inline; filename="${id}.${asset.extension}"`});
    if(req.headers.range){
      const match=/^bytes=(\d*)-(\d*)$/.exec(req.headers.range);
      if(!match||(!match[1]&&!match[2]))return res.status(416).set('Content-Range',`bytes */${bytes.length}`).end();
      let start=match[1]?Number(match[1]):Math.max(0,bytes.length-Number(match[2]));
      let end=match[1]&&match[2]?Number(match[2]):bytes.length-1;
      if(!Number.isSafeInteger(start)||!Number.isSafeInteger(end)||start>=bytes.length||start>end)return res.status(416).set('Content-Range',`bytes */${bytes.length}`).end();
      end=Math.min(end,bytes.length-1);return res.status(206).set({'Content-Range':`bytes ${start}-${end}/${bytes.length}`,'Content-Length':end-start+1}).send(bytes.subarray(start,end+1));
    }
    res.set('Content-Length',bytes.length).send(bytes);
  }catch(error){console.error('Private recording access failed:',error.code||error.name);res.status(502).json({success:false,message:'Unable to load the recording. Please retry.'});}
});
const getUserToken = async (id) => {
  const [rows] = await db.query("SELECT token FROM users WHERE id = ?", [id])
  return rows[0]?.token || null
}
const allowedStatuses = ["Issue Raised", "Verification pending", "Invalid Report", "In Progress", "Resolved"]

const statusColor = (status) => status === "Invalid Report" ? "rgba(197, 0, 0, 1)"
  : status === "In Progress" ? "rgba(255, 187, 0, 1)"
  : status === "Resolved" ? "rgba(0, 165, 6, 1)"
  : status === "Issue Raised" ? "rgba(40, 0, 121, 1)"
  : status === "Verification pending" ? "rgba(0, 0, 0, 1)"
  : "rgb(255,255,255)"

const parseLocation = (value) => {
  if (typeof value !== "string") return value
  try {
    return JSON.parse(value)
  } catch (_) {
    return value
  }
}

const formatReport = (row) => ({ ...row, location: parseLocation(row.location) })
const enrichReports = async (rows, userId) => {
  await community.ensureSchema();
  const publicRows=await community.aggregateMany(rows,userId);
  return rows.map((row,index)=>({...formatReport(row),...publicRows[index]}));
}
const enrichReport = async (row,userId) => (await enrichReports([row],userId))[0];

router.get("/getAllReports", requireAuth, async (req, res) => {
  try {
    const [rawRows] = await db.query("SELECT * FROM reports WHERE status <> 'Invalid Report' OR userID = ?",[req.userId]);
    const rows=await enrichReports(rawRows,req.userId);
    const markers = rows.map((row) => ({
      Rid: row.Rid,
      issue: row.issue,
      priority: row.priority,
      confirmationCount: row.confirmationCount,
      lat: parseLocation(row.location)?.lat,
      lng: parseLocation(row.location)?.lng,
      status: row.status,
      isOwner: String(row.userID) === String(req.userId),
      color: statusColor(row.status),
    })).filter((row) => row.lat != null && row.lng != null && Number.isFinite(Number(row.lat)) && Number.isFinite(Number(row.lng)))
    res.json(markers);
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Unable to load reports" });
  }
})

router.post("/getUserReports", requireAuth, async (req, res) => {
  const userID = req.userId;
  if (userID === undefined || userID === null || String(userID).trim() === "") {
    return res.status(400).json({ success: false, message: "userID is required" });
  }
  try {
    const [rows] = await db.query(
      `SELECT Rid, priority, userID, issue, description, location, createdAt, imageURL, audioURL, pdfURL, status
       FROM reports WHERE userID = ? ORDER BY createdAt DESC`,
      [userID],
    );
    res.json(await enrichReports(rows,req.userId));
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Unable to load user reports" });
  }
})

router.post("/getReportData", requireAuth, async (req, res) => {
  const { Rid } = req.body;
  const userID = req.userId;
  if (!Rid) return res.status(400).json({ success: false, message: "Rid is required" });
  try {
    const query = userID === undefined || userID === null
      ? "SELECT Rid, priority, userID, issue, description, location, imageURL, audioURL, pdfURL, resolutionNote, resolvedAt, resolvedBy, createdAt, status FROM reports WHERE Rid = ?"
      : "SELECT Rid, priority, userID, issue, description, location, imageURL, audioURL, pdfURL, resolutionNote, resolvedAt, resolvedBy, createdAt, status FROM reports WHERE Rid = ? AND userID = ?"
    const params = userID === undefined || userID === null ? [Rid] : [Rid, userID]
    const [rows] = await db.query(query, params);
    if (rows.length === 0) return res.status(404).json({ success: false, message: "Report not found" });
    const report = await enrichReport(rows[0],req.userId);
    return res.json(report);
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Unable to load report" });
  }
})

router.post("/getReportStatusHistory", requireAuth, async (req, res) => {
  const { Rid } = req.body;
  if (!Rid) return res.status(400).json({ success: false, message: "Rid is required" });
  try {
    const [rows] = await db.query(
      `SELECT h.id, h.Rid, h.previousStatus, h.newStatus, h.changedAt, h.source
       FROM report_status_history h
       INNER JOIN reports r ON r.Rid = h.Rid
       WHERE h.Rid = ? AND r.userID = ? ORDER BY h.changedAt ASC, h.id ASC`,
      [Rid, req.userId],
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Unable to load report status history" });
  }
})
router.post("/getPublicReportData", requireAuth, async (req, res) => {
  const { Rid } = req.body;
  if (!Rid) return res.status(400).json({ success: false, message: "Rid is required" });
  try {
    const [rows] = await db.query(
      "SELECT * FROM reports WHERE Rid = ?",
      [Rid],
    );
    if (rows.length === 0) return res.status(404).json({ success: false, message: "Report not found" });
    if(rows[0].status==='Invalid Report'&&String(rows[0].userID)!==req.userId)return res.status(404).json({success:false,message:'Report not found'});
    await community.ensureSchema();
    return res.json(await community.aggregate(rows[0],req.userId));
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Unable to load public report" });
  }
})
router.post('/getReportByLocation', async (req, res) => {
  const {lat, lng} = req.body;
  try {
    const [rows] = await db.query(`SELECT Rid, imageURL, issue, CAST(JSON_UNQUOTE(JSON_EXTRACT(location, '$.lat')) AS DECIMAL(10,7)) AS lat, CAST(JSON_UNQUOTE(JSON_EXTRACT(location, '$.lng')) AS DECIMAL(10,7)) AS lng FROM reports
      WHERE CAST(JSON_UNQUOTE(JSON_EXTRACT(location, '$.lat')) AS DECIMAL(10,7))
              BETWEEN (? - 0.0001) AND (? + 0.0001)
        AND CAST(JSON_UNQUOTE(JSON_EXTRACT(location, '$.lng')) AS DECIMAL(10,7))
              BETWEEN (? - 0.0001) AND (? + 0.0001);
      `, [lat, lat, lng, lng])
      console.log(rows);
      return res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Unable to load nearby reports" });
  }
})

router.post("/getAuthorityReports", requireAuth, requireAuthority, async (req, res) => {
  const requestedStatus = req.body?.status
  if (requestedStatus && !allowedStatuses.includes(requestedStatus)) {
    return res.status(400).json({ success: false, message: "Invalid report status" })
  }
  try {
    const query = requestedStatus
      ? `SELECT Rid, priority, userID, issue, description, location, imageURL, audioURL, pdfURL, resolutionNote, resolvedAt, resolvedBy, createdAt, status
         FROM reports WHERE status = ? ORDER BY createdAt DESC`
      : `SELECT Rid, priority, userID, issue, description, location, imageURL, audioURL, pdfURL, resolutionNote, resolvedAt, resolvedBy, createdAt, status
         FROM reports WHERE status IN (?, ?, ?) ORDER BY createdAt DESC`
    const params = requestedStatus ? [requestedStatus] : ["Issue Raised", "Verification pending", "In Progress"]
    const [rows] = await db.query(query, params)
    return res.json(await enrichReports(rows,req.userId))
  } catch (err) {
    console.error(err)
    return res.status(500).json({ success: false, message: "Unable to load authority reports" })
  }
})

router.post("/getAuthorityReportData", requireAuth, requireAuthority, async (req, res) => {
  const { Rid } = req.body
  if (!Rid) return res.status(400).json({ success: false, message: "Rid is required" })
  try {
    const [rows] = await db.query(
      `SELECT Rid, priority, userID, issue, description, location, imageURL, audioURL, pdfURL, resolutionNote, resolvedAt, resolvedBy, createdAt, status
       FROM reports WHERE Rid = ?`,
      [Rid],
    )
    if (rows.length === 0) return res.status(404).json({ success: false, message: "Report not found" })
    return res.json(await enrichReport(rows[0],req.userId))
  } catch (err) {
    console.error(err)
    return res.status(500).json({ success: false, message: "Unable to load authority report" })
  }
})

const validTransitions = {
  "Issue Raised": ["Verification pending"],
  "Verification pending": ["Invalid Report", "In Progress"],
  "In Progress": ["Resolved"],
}

router.post("/updateReportStatus", requireAuth, requireAuthority, async (req, res) => {
  const { Rid, status, resolutionNote } = req.body || {}
  if (!Rid || !status) return res.status(400).json({ success: false, message: "Rid and status are required" })
  if (!allowedStatuses.includes(status)) return res.status(400).json({ success: false, message: "Invalid report status" })
  try {
    const [rows] = await db.query("SELECT Rid, userID, status FROM reports WHERE Rid = ?", [Rid])
    if (rows.length === 0) return res.status(404).json({ success: false, message: "Report not found" })
    const report = rows[0]
    if (!validTransitions[report.status]?.includes(status)) {
      return res.status(409).json({ success: false, message: `Cannot move report from ${report.status} to ${status}` })
    }
    if (resolutionNote && String(resolutionNote).length > 2000) return res.status(400).json({ success: false, message: "Resolution note must be under 2000 characters" })
    if (status === "Resolved" && (!resolutionNote || String(resolutionNote).trim() === "")) {
      return res.status(400).json({ success: false, message: "Resolution note is required" })
    }
    const resolvedAt = status === "Resolved" ? new Date() : null
    const connection = await db.getConnection()
    try {
      await connection.beginTransaction()
      const [update] = await connection.query(
        `UPDATE reports SET status = ?, resolutionNote = ?, resolvedAt = ?, resolvedBy = ? WHERE Rid = ? AND status = ?`,
        [status, status === "Resolved" ? String(resolutionNote).trim() : null, resolvedAt, status === "Resolved" ? req.userId : null, Rid, report.status],
      )
      if (update.affectedRows !== 1) {
        await connection.rollback()
        return res.status(409).json({ success: false, message: 'Report changed during review. Refresh and try again.' })
      }
      await connection.query(
        `INSERT INTO report_status_history (Rid, previousStatus, newStatus, actorUserID, source) VALUES (?, ?, ?, ?, ?)`,
        [Rid, report.status, status, req.userId, "authority"],
      )
      await connection.commit()
    } catch (error) {
      await connection.rollback()
      throw error
    } finally { connection.release() }

    const token = await getUserToken(report.userID)
    if (token) {
      const messages = {
        "Verification pending": ["Report under review", `Report ${Rid} is now awaiting authority verification.`],
        "Invalid Report": ["Report verification result", `Report ${Rid} was marked invalid.`],
        "In Progress": ["Report accepted", `Work on report ${Rid} is now in progress.`],
        "Resolved": ["Report resolved", `Report ${Rid} has been marked resolved.`],
      }
      const notification = messages[status]
      if (notification) {
        try {
          await sendNotification(token, notification[0], notification[1])
        } catch (notificationError) {
          console.error("Status notification failed:", notificationError)
        }
      }
    }
    const [updatedRows] = await db.query(
      `SELECT Rid, priority, userID, issue, description, location, imageURL, audioURL, pdfURL, resolutionNote, resolvedAt, resolvedBy, createdAt, status
       FROM reports WHERE Rid = ?`,
      [Rid],
    )
    return res.json({ success: true, report: await enrichReport(updatedRows[0],req.userId) })
  } catch (err) {
    console.error(err)
    return res.status(500).json({ success: false, message: "Unable to update report status" })
  }
})
module.exports = router;
