const assert = require("node:assert/strict")
const test = require("node:test")
const { parsePredictionText } = require("./services/IssueDetection")

test("parses fenced Gemini prediction JSON", () => {
  const result = parsePredictionText("```json\n[{\"issue\":\"Pothole\",\"probability\":0.9,\"description\":\"Road damage\",\"bounding_box\":[1,2,3,4]}]\n```")
  assert.equal(result[0].issue, "Pothole")
  assert.deepEqual(result[0].bounding_box, [1, 2, 3, 4])
})

test("preserves a valid empty prediction result", () => {
  assert.deepEqual(parsePredictionText("[]"), [])
})

test("rejects malformed Gemini prediction JSON", () => {
  assert.throws(() => parsePredictionText("{\"answer\":\"unknown\"}"), /unexpected prediction structure/)
})