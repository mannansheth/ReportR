const multer = require("multer");

const storage = multer.memoryStorage();
const upload = multer({ 
  storage,
  limits: {
    files: 3,
    fields: 20,
    fileSize: 25 * 1024 * 1024, // 25MB (AssemblyAI limit)
  }
}); 
module.exports = upload;