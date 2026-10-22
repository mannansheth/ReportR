const axios = require('axios');
const FormData = require('form-data');
const dotenv = require("dotenv");
const { Readable } = require("stream");
const fs = require("fs")
dotenv.config();
const {
  ASSEMBLY_API_KEY 
} = process.env

const ffmpeg = require('fluent-ffmpeg');
const { PassThrough } = require('stream');

function bufferToMp3(buffer) {
  return new Promise((resolve, reject) => {
    const input = new PassThrough();
    input.end(buffer);

    const output = new PassThrough();
    const chunks = [];

    ffmpeg(input)
      .format('mp3')
      .on('error', reject)
      .on('end', () => {
        resolve(Buffer.concat(chunks));
      })
      .pipe(output, { end: true });

    output.on('data', chunk => chunks.push(chunk));
  });
}

async function transcribeAudio(buffer) {
  if (!ASSEMBLY_API_KEY) {
    throw new Error('ASSEMBLYAI_API_KEY environment variable is required');
  }

  try {



    const uploadResponse = await axios.post(
      'https://api.assemblyai.com/v2/upload',
      buffer,
      {
        headers: {
          "Content-Type": "application/octet-stream",
          'Authorization': ASSEMBLY_API_KEY
        }
      }
    ); 

    const audioUrl = uploadResponse.data.upload_url;
    const transcriptResponse = await axios.post(
      'https://api.assemblyai.com/v2/transcript',
      {
        audio_url: audioUrl,
        language_detection: true,
        punctuate: true,
        format_text: true
      },
      {
        headers: {
          'Authorization': ASSEMBLY_API_KEY,
          'Content-Type': 'application/json'
        }
      }
    );

    const transcriptId = transcriptResponse.data.id;

    let attempts = 0;
    const maxAttempts = 60; 

    while (attempts < maxAttempts) {
      const pollResponse = await axios.get(
        `https://api.assemblyai.com/v2/transcript/${transcriptId}`,
        {
          headers: {
            'Authorization': ASSEMBLY_API_KEY
          }
        }
      );

      const transcript = pollResponse.data;
      if (transcript.status === 'completed') {
        
        return {
          text: transcript.text,
          confidence: transcript.confidence,
          duration: transcript.audio_duration
        };
      } else if (transcript.status === 'error') {
        throw new Error(`Transcription failed: ${transcript.error}`);
      }
      // Wait before next poll (exponential backoff)
      const waitTime = Math.min(1000 * Math.pow(1.2, attempts), 5000);
      await new Promise(resolve => setTimeout(resolve, waitTime));
      attempts++;
    }

    throw new Error('Transcription timeout - took too long to complete');

  } catch (error) {
    console.error('Transcription error:', error.message);
    throw new Error(`Transcription failed: ${error.message}`);
  }
}

module.exports = { transcribeAudio };