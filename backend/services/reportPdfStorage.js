const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const cloudinary = require('../config/cloudinaryConfig');

const directory = path.resolve(__dirname, '../data/reports');
const MAX_PDF_BYTES = 25 * 1024 * 1024;
const validId = (id) => /^[A-Za-z0-9_-]{1,80}$/.test(String(id));
const isPdf = (buffer) => Buffer.isBuffer(buffer) && buffer.length >= 5 && buffer.length <= MAX_PDF_BYTES && buffer.subarray(0, 5).toString() === '%PDF-';
function filePath(id) {
  if (!validId(id)) throw new Error('Invalid report ID');
  return path.join(directory, `${id}.pdf`);
}

async function saveReportPdf(id, bytes) {
  if (!isPdf(bytes)) throw new Error('Invalid PDF document');
  const destination = filePath(id);
  await fs.mkdir(directory, { recursive: true });
  const temporary = `${destination}.${crypto.randomUUID()}.tmp`;
  try {
    await fs.writeFile(temporary, bytes, { mode: 0o600, flag: 'wx' });
    await fs.rename(temporary, destination);
  } finally {
    await fs.rm(temporary, { force: true });
  }
  return bytes;
}

async function readReportPdf(id) {
  try {
    const bytes = await fs.readFile(filePath(id));
    return isPdf(bytes) ? bytes : null;
  } catch (error) {
    if (error.code === 'ENOENT') return null;
    throw error;
  }
}

// Build signed original-download requests only for this account's own report
// folder. The signed URL and Cloudinary credentials never leave the server.
function originalDownloadUrl(id, remoteUrl) { return require('./privateMedia').signedOriginal(id,remoteUrl,'pdf'); }

async function recoverReportPdf(id, remoteUrl) {
  const signedUrl = originalDownloadUrl(id, remoteUrl);
  if (!signedUrl) return null;
  const response = await fetch(signedUrl, { signal: AbortSignal.timeout(30000), redirect: 'error' });
  if (!response.ok || Number(response.headers.get('content-length')) > MAX_PDF_BYTES) return null;
  const chunks = [];
  let size = 0;
  for await (const chunk of response.body) {
    size += chunk.length;
    if (size > MAX_PDF_BYTES) {
      await response.body.cancel().catch(() => {});
      throw new Error('PDF is too large');
    }
    chunks.push(Buffer.from(chunk));
  }
  const bytes = Buffer.concat(chunks);
  return isPdf(bytes) ? saveReportPdf(id, bytes) : null;
}

module.exports = { saveReportPdf, readReportPdf, recoverReportPdf, originalDownloadUrl, isPdf, validId };
