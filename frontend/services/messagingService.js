import axios from 'axios';
const backendURL = process.env.EXPO_PUBLIC_BACKEND_URL;
export const sendNotification = async (Rid, name, userId) => {
  try {
    console.log(name);
    const response = await axios.post(`${backendURL}api/user/sendNotification`, {
      Rid: Rid,
      name:name,
      userId: userId
    })
    return response.data.status;
  } catch (err) {
    // console.error(err);
    throw err;
  }
}