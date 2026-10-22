import { PDFDocument } from "pdf-lib";
import * as FileSystem from "expo-file-system/legacy";
import { Alert } from "react-native";
import { PDFTEMPLATE } from "./templates/pdfTemplate";


// Base64 → Uint8Array converter
function base64ToUint8Array(base64) {
  const binary = globalThis.atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// Clean text for PDF (removes problematic characters)
function cleanText(text) {
  if (!text) return "";
  return String(text)
    .replace(/[\u202F\u00A0]/g, " ") // fix non-breaking spaces
    .replace(/[^\x20-\x7E]/g, " ") // replace non-ASCII
    .trim();
}

export const generatePDF = async (reportData, imageUri) => {
  try {

    // Load PDF template from embedded base64 (100% offline)
    const pdfBytes = base64ToUint8Array(PDFTEMPLATE);


    const pdfDoc = await PDFDocument.load(pdfBytes);
    const page = pdfDoc.getPage(0);

    const { width, height } = page.getSize();
    console.log(`Page size: ${width} x ${height}`);


    // Field coordinates from template
    const fields = {
      reportId: { x: 175, y: 795, size: 18 },
      date: { x: 640, y: 1015, size: 20 },
      time: { x: 550, y: 1015, size: 20 },
      name: { x: 130, y: 750, size: 20 },
      number: { x: 155, y: 700, size: 20 },
      category: { x: 80, y: 515, size: 20 },
      description: { x: 80, y: 350, size: 20 },
      lat: { x: 80, y: 210, size: 20 },
      long: { x: 200, y: 210, size: 20 },
      location: { x: 80, y: 185, size: 18 },
      location1: { x: 80, y: 160, size: 18 },
    };

    // Write text to PDF
    page.drawText(cleanText(reportData.reportID), fields.reportId);

    page.drawText(
      cleanText(new Date(reportData.createdDate).toLocaleTimeString()),
      fields.time
    );
    page.drawText(
      cleanText(
        new Date(reportData.createdDate).toLocaleDateString("en-IN")
      ),
      fields.date
    );

    page.drawText(cleanText(reportData.name), fields.name);
    if (reportData.number) {
      page.drawText(cleanText(reportData.number), fields.number);
    }

    page.drawText(cleanText(reportData.category), fields.category);
    page.drawText(cleanText(reportData.description), fields.description);

    page.drawText(cleanText(reportData.location?.lat + ", " || ""), fields.lat);
    page.drawText(cleanText(reportData.location?.lng || ""), fields.long);

    // Split location into two lines at 4th last comma
    const [loc1, loc2] = [
      reportData.location?.loc.split(",").slice(0, -4).join(","),
      reportData.location?.loc.split(",").slice(-4).join(","),
    ];

    page.drawText(cleanText(loc1 || ""), fields.location);
    page.drawText(cleanText(loc2 || ""), fields.location1);

    // Add image if provided
    if (imageUri) {
      try {
        const imgBase64 = await FileSystem.readAsStringAsync(imageUri, {
          encoding: FileSystem.EncodingType.Base64,
        });
        const imageBytes = base64ToUint8Array(imgBase64);

        let image;
        try {
          image = await pdfDoc.embedJpg(imageBytes);
        } catch {
          image = await pdfDoc.embedPng(imageBytes);
        }

        page.drawImage(image, {
          x: 465,
          y: 610,
          width: 220,
          height: 280,
        });
      } catch (error) {
        console.warn("Failed to add image:", error);
      }
    }

    // Save final PDF
    const pdfBytesFinal = await pdfDoc.save();

    // Ensure directory exists
    const dirUri = `${FileSystem.documentDirectory}reports/${reportData.reportID}/`;
    const dirInfo = await FileSystem.getInfoAsync(dirUri);
    if (!dirInfo.exists) {
      await FileSystem.makeDirectoryAsync(dirUri, { intermediates: true });
    }

    const fileUri = `${dirUri}report.pdf`;

    // Convert to base64 + save
    let binary = "";
    for (let i = 0; i < pdfBytesFinal.length; i++) {
      binary += String.fromCharCode(pdfBytesFinal[i]);
    }
    const base64 = globalThis.btoa(binary);

    await FileSystem.writeAsStringAsync(fileUri, base64, {
      encoding: FileSystem.EncodingType.Base64,
    });

    return fileUri;
  } catch (error) {
    console.error("PDF generation failed:", error);
    Alert.alert("Error", `PDF generation failed: ${error.message}`);
    throw error;
  }
};