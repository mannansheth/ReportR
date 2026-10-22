import axios from 'axios';
const backendURL = process.env.EXPO_PUBLIC_BACKEND_URL?.replace(/\/?$/, "/");

const getBackendURL = () => {
  if (!backendURL) {
    throw new Error("Missing EXPO_PUBLIC_BACKEND_URL. Set it in frontend/.env and restart Expo.");
  }

  return backendURL;
}

export const getAllReports = async () => {
  try {
    const response = await axios.get(`${getBackendURL()}api/reports/getAllReports`);
    return response.data;
  } catch (err) {
    console.error("Error fetching reports:", err?.message || err);
    throw err;
  }
}
export const getReportData = async (Rid ) => {
  try {
    const response = await axios.post(`${getBackendURL()}api/reports/getReportData`, {
      Rid: Rid
    });
    return response.data;
  } catch (err) {
    console.error("Error fetching report data:", err?.message || err);
    throw err;
  }
}
export const getReportByLocation = async (lat, lng) => {
  try {
    const response = await axios.post(`${getBackendURL()}api/reports/getReportByLocation`, {
      lat,
      lng
    })
    return response.data;
  } catch (err) {
    console.error("Error fetching reports by location:", err?.message || err);
    throw err;
  }
}
