const mysql = require("mysql2/promise");
const dotenv = require("dotenv")
dotenv.config({ path: require("path").resolve(__dirname, "../.env"), quiet: true })
const {
    MYSQL_HOST, 
    MYSQL_USER, 
    MYSQL_PASS, 
    MYSQL_DB} = process.env;

const db = mysql.createPool({
    host : MYSQL_HOST,
    user : MYSQL_USER,
    password: MYSQL_PASS,
    database: MYSQL_DB,
    waitForConnections: true,
  connectionLimit: 5,
  queueLimit: 0
});

db.on('connection', (conn) => {
  conn.on('error', err => {
    if (err.code === 'PROTOCOL_CONNECTION_LOST') {
      console.error("MySQL connection lost, reconnecting...");
    }
  });
});

module.exports = db