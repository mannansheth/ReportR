const jwt = require("jsonwebtoken")
const db = require("../config/dbConfig")

const requireAuth = async (req, res, next) => {
  const header = req.headers.authorization || ""
  const [scheme, token] = header.split(" ")
  if (scheme !== "Bearer" || !token || !process.env.JWT_SECRET) {
    return res.status(401).json({ success: false, message: "Authentication required" })
  }
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET)
    if (!payload?.userId) return res.status(401).json({ success: false, message: "Invalid authentication token" })
    const [rows] = await db.query("SELECT id, role FROM users WHERE id = ?", [payload.userId])
    if (rows.length === 0) return res.status(401).json({ success: false, message: "Invalid authentication identity" })
    req.userId = String(rows[0].id)
    req.userRole = rows[0].role || "Citizen"
    next()
  } catch (error) {
    if (error.name !== 'JsonWebTokenError' && error.name !== 'TokenExpiredError' && error.name !== 'NotBeforeError') {
      console.error('Authentication database unavailable:', error.code || error.message);
      return res.status(503).json({ success: false, message: 'Account service is temporarily unavailable. Try again.' });
    }
    return res.status(401).json({ success: false, message: "Invalid or expired authentication token" })
  }
}

const requireAuthority = (req, res, next) => {
  if (req.userRole !== "Authority" && req.userRole !== "Admin") {
    return res.status(403).json({ success: false, message: "Authority access required" })
  }
  next()
}

module.exports = { requireAuth, requireAuthority }
