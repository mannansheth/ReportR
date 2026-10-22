const db = require("../config/dbConfig")

const statements = [
  "ALTER TABLE users ADD COLUMN role VARCHAR(30) NOT NULL DEFAULT 'Citizen'",
  "ALTER TABLE reports ADD COLUMN resolutionNote TEXT NULL, ADD COLUMN resolvedAt DATETIME NULL, ADD COLUMN resolvedBy INT NULL",
]

;(async () => {
  for (const statement of statements) {
    try {
      await db.query(statement)
    } catch (error) {
      if (!error.message.includes("Duplicate column")) throw error
    }
  }
  console.log("Authority migration applied")
})().catch((error) => {
  console.error(error.message)
  process.exitCode = 1
}).finally(() => db.end())
