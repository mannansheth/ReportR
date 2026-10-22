require("dotenv").config({ path: require("path").resolve(__dirname, ".env"), quiet: true });
const express = require("express")
const axios = require("axios")
const dotenv = require("dotenv")
const cors = require("cors")
const { detectIssues, GeminiPredictionError } = require("./services/IssueDetection")
const upload = require("./config/multerConfig")
const { transcribeAudio } = require("./services/Transcribe")
const userRoutes = require("./services/userRoutes")
const reportRoutes = require("./services/reportRoutes")
const fs = require("fs")
const {
  PORT
} = process.env;
const app = express()
app.use(cors({ origin: "*", credentials: true }));
app.use(express.json({ limit: "10mb" }));

app.use('/api/user', userRoutes);
app.use('/api/reports', require('./services/communityRoutes'));
app.use('/api/reports', reportRoutes)
app.get('/', (req, res) => {
  res.json({"Hello":"Working"})
})

app.post("/api/transcribeDescription", upload.single("audio"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No audio file received' });
    }

    if (!req.file.buffer || req.file.buffer.length === 0) {
      return res.status(400).json({ error: 'Received empty audio file' });
    }
    const result = await transcribeAudio(
      req.file.buffer
    )

    res.json({success:true, result:result});
  } catch (err) {
    console.error(err);

    res.status(502).json({success:false, message: "Audio transcription is unavailable. Please enter the description manually."});
  }
})

app.post("/api/getPredictions", async (req, res) => {
  const { base64Image, mimeType } = req.body;
  try {
    const predictions = await detectIssues(base64Image, mimeType);
    res.json(predictions);
  } catch (err) {
    console.error("Prediction request failed:", err)
    const statusCode = err instanceof GeminiPredictionError ? err.statusCode : 502;
    const code = err instanceof GeminiPredictionError ? err.code : "PREDICTION_SERVICE_ERROR";
    res.status(statusCode).json({
      success: false,
      code,
      message: err instanceof GeminiPredictionError ? err.message : "Prediction service failed.",
    });
  }
})
app.use((err, req, res, next) => {
  if (res.headersSent) return next(err);
  console.error("Request failed:", err.code || err.message);
  const status = err.code === "LIMIT_FILE_SIZE" ? 413 : err.status || 500;
  res.status(status).json({ success: false, message: status === 413 ? "Each attachment must be under 25 MB" : status === 400 ? "Invalid request body" : "Request could not be completed" });
});
if (require.main === module) {
  app.listen(PORT || 5000, "0.0.0.0", () => console.log(`ReportR backend listening on ${PORT || 5000}`));
}
module.exports = app;