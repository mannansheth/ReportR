const dotenv = require("dotenv")
dotenv.config();

const { GEMINI_API_KEY } = process.env
const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-3.1-flash-lite"

class GeminiPredictionError extends Error {
  constructor(message, code = "GEMINI_ERROR", statusCode = 502) {
    super(message)
    this.name = "GeminiPredictionError"
    this.code = code
    this.statusCode = statusCode
  }
}

const SYSTEM_PROMPT = `You are an expert at analyzing images for civic issues. Your task is to carefully examine the provided image and identify any civic issues. A civic issue is any problem in a public space that requires maintenance or attention from a local authority. Examples include, but are not limited to, potholes, broken street lights, garbage overflow, traffic violations, damaged signage, graffiti, and infrastructure damage.

Respond ONLY with a JSON array of objects. Each object in the array MUST have six keys:

"issue" (a string corresponding to the detected issue)

"probability" (a floating-point number from 0 to 1, representing your confidence in the detection, include items with less confidence as well)

"description" (a brief, one-sentence string describing the issue in the image)

"bounding_box" (an array of four integers [ymin, xmin, ymax, xmax] representing the coordinates of the issue on a 1000x1000 grid. These are normalized coordinates and must be scaled for your image.)

If no civic issues are detected, return an empty JSON array: []. Make sure detected issues are genuine civic problems that can be resolved by a municipal authority. Do not include any other text, explanation, or markdown formatting outside of the JSON array.`

function parsePredictionText(text) {
  const cleaned = text.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "")
  let parsed
  try {
    parsed = JSON.parse(cleaned)
  } catch (_) {
    throw new GeminiPredictionError("Gemini returned invalid prediction JSON.", "GEMINI_INVALID_RESPONSE")
  }

  const predictions = Array.isArray(parsed) ? parsed : parsed?.predictions
  if (!Array.isArray(predictions)) {
    throw new GeminiPredictionError("Gemini returned an unexpected prediction structure.", "GEMINI_INVALID_RESPONSE")
  }

  for (const prediction of predictions) {
    const box = prediction?.bounding_box
    if (
      typeof prediction?.issue !== "string" ||
      typeof prediction?.probability !== "number" ||
      typeof prediction?.description !== "string" ||
      !Array.isArray(box) ||
      box.length !== 4 ||
      box.some((value) => !Number.isFinite(value))
    ) {
      throw new GeminiPredictionError("Gemini returned an invalid prediction item.", "GEMINI_INVALID_RESPONSE")
    }
  }

  return predictions
}

const detectIssues = async (base64Image, mimeType) => {
  if (!GEMINI_API_KEY) {
    throw new GeminiPredictionError("Gemini is not configured.", "GEMINI_NOT_CONFIGURED", 503)
  }
  if (typeof base64Image !== "string" || base64Image.length === 0 || typeof mimeType !== "string" || !mimeType.startsWith("image/")) {
    throw new GeminiPredictionError("A valid base64 image and image MIME type are required.", "INVALID_IMAGE", 400)
  }

  const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`
  const payload = {
    contents: [
      {
        parts: [
          {
            inlineData: {
              mimeType,
              data: base64Image,
            },
          },
        ],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
    },
    systemInstruction: {
      parts: [{ text: SYSTEM_PROMPT }],
    },
  }

  let response
  try {
    response = await fetch(apiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    })
  } catch (error) {
    console.error("Error connecting to Gemini API:", error)
    throw new GeminiPredictionError("Gemini is unavailable.", "GEMINI_UNAVAILABLE", 503)
  }

  const responseText = await response.text()
  if (!response.ok) {
    console.error("Gemini API error:", response.status, responseText.slice(0, 500))
    throw new GeminiPredictionError("Gemini rejected the prediction request.", "GEMINI_API_ERROR", 502)
  }

  let data
  try {
    data = JSON.parse(responseText)
  } catch (_) {
    throw new GeminiPredictionError("Gemini returned an invalid API response.", "GEMINI_INVALID_RESPONSE")
  }

  const jsonString = data?.candidates?.[0]?.content?.parts?.find((part) => typeof part?.text === "string")?.text
  if (!jsonString) {
    const reason = data?.promptFeedback?.blockReason || data?.candidates?.[0]?.finishReason
    console.error("Gemini returned no prediction text:", reason || "unknown reason")
    throw new GeminiPredictionError("Gemini returned no usable prediction response.", "GEMINI_EMPTY_RESPONSE")
  }

  return parsePredictionText(jsonString)
}

module.exports = { detectIssues, parsePredictionText, GeminiPredictionError, GEMINI_MODEL }