const admin = require('firebase-admin');

// Initialize Firebase Admin SDK once (in your server entry file, e.g. app.js)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(require('../firebase-service-key.json')), // Firebase service account key
  });
}


const sendNotification = async (token, title, body) => {
  try {
        const messageId = await admin.messaging().send({
          token: token,
          notification: {
            title: title,
            body: body,
          },
          android: {
            notification: {
              icon: "ic_stat_name",     // small icon in res/drawable
              color: "#2196f3",         // optional accent color
              sound:"default",         // play default notification sound
              channelId: "default",     // must exist in app for Android 8+
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        });
        console.log('[FCM] Message accepted by Firebase, ID:', messageId);
        return true;
  } catch (err) {
    console.error('[FCM] Delivery failed:', err.code || err.message);
    throw err;
  }
}
module.exports = { sendNotification }
