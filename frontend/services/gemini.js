import axios from "axios";

const backendURL = process.env.EXPO_PUBLIC_BACKEND_URL
export const detectIssues = async (base64Image, mimeType) => {
  try {
    const response = await axios.post(`${backendURL}api/getPredictions`, {
      base64Image,
      mimeType,
    })
    console.log(response.data);
    return response.data || [];
  } catch (err) {
    // console.error(err);
    return []
  }
}

export const submitReport = async (reportData) => {
  try {
    const formData = new FormData();
    console.log(reportData.createdDate)
    formData.append("reportID", reportData.reportID);
    formData.append("userID", reportData.userID);
    formData.append("name", reportData.name);
    formData.append("number", reportData.number);
    formData.append("category", reportData.category);
    formData.append("description", reportData.description);
    formData.append("location", JSON.stringify(reportData.location));
    formData.append("createdDate", reportData.createdDate);
    if (reportData.image) {
      formData.append("image", {
        uri:reportData.image,
        name: "report_image.jpg",
        type: "image/jpeg",
      });
    }

    if (reportData.audio) {
      formData.append("audio", {
        uri: reportData.audio,
        name: "report_audio.m4a",
        type: "audio/m4a",
      });
    }

    if (reportData.pdf) {
      formData.append("pdf", {
        uri: reportData.pdf,   // now this is the fileUri string
        name: "report.pdf",
        type: "application/pdf",
      });
    }
    console.log(reportData.reportID)
    const response = await axios.post(
      `${backendURL}api/user/submitReport`,
      formData,
      { headers: { "Content-Type": "multipart/form-data" } }
    );

    return response.data;
  } catch (err) {
    // console.error("Error submitting report:", err);
    // throw err;
    return false;
  }
};
