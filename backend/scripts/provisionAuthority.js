require("dotenv").config()
const db = require("../config/dbConfig")

const phone = process.env.AUTHORITY_PHONE
const name = process.env.AUTHORITY_NAME || "ReportR Authority"

if (!phone) {
  console.error("AUTHORITY_PHONE is required")
  process.exitCode = 1
} else {
  db.query("UPDATE users SET role = 'Authority', name = ? WHERE number = ?", [name, phone])
    .then(([result]) => {
      if (result.affectedRows === 0) {
        console.error("No existing user matched AUTHORITY_PHONE. Authenticate that number once first, then run this script again.")
        process.exitCode = 1
      } else {
        console.log("Authority role provisioned for the configured account.")
      }
    })
    .catch((error) => {
      console.error("Unable to provision authority role:", error.message)
      process.exitCode = 1
    })
    .finally(() => db.end())
}
