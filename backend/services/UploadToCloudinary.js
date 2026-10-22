const cloudinary = require("../config/cloudinaryConfig");

const uploadToCloudinary = async (file, filename, type, Rid) => {
  let fileBuffer;
  if (type === "image" && typeof file === "string" && file.startsWith("data:")) {
    const base64Data = file.split(",")[1]; // remove "data:image/png;base64,"
    fileBuffer = Buffer.from(base64Data, "base64");
  } else {
    fileBuffer = file; // already a Buffer
  }

  return new Promise((resolve, reject) => {
    cloudinary.uploader.upload_stream(
      {
        resource_type: type === 'audio' ? 'video' : type === 'pdf' ? 'raw' : 'image',
        type: type === 'audio' || type === 'pdf' ? 'authenticated' : 'upload',
        public_id: type === 'pdf' ? `${filename.split('.')[0]}.pdf` : filename.split('.')[0],
        folder: `reportr/reports/${Rid}`,
      },
      (error, result) => {
        if (error) reject(error);
        else {
          if (type === 'audio' || type === 'pdf') result.secure_url = require('./privateMedia').unsignedDeliveryUrl(result.secure_url);
          resolve(result);
        }
      }
    ).end(fileBuffer);
  });
};

module.exports = { uploadToCloudinary };
