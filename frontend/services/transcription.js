import axios from 'axios';

const backendURL = process.env.EXPO_PUBLIC_BACKEND_URL
export const transcribeDesc = async (audioUri) => {
  if (!audioUri) return { success: false };

  try {
    const formData = new FormData();
    formData.append('audio', {
      uri: audioUri,
      type: 'audio/m4a',
      name: 'recording.m4a',
    });

    const response = await axios.post(
      `${backendURL}api/transcribeDescription`,
      formData,
      {
        headers: { 'Content-Type': 'multipart/form-data' },
        timeout: 120000, // 2 min timeout
      }
    );

    // return only the data, not the whole axios response
    return response.data;
  } catch (error) {
    // console.error('Upload failed:', error.response?.data || error.message);
    return { success: false, error: error.message };
  }
};