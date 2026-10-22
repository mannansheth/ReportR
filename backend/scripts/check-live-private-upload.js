require('../config/dbConfig');
const db=require('../config/dbConfig'),cloudinary=require('../config/cloudinaryConfig'),{uploadToCloudinary}=require('../services/UploadToCloudinary'),media=require('../services/privateMedia'),assert=require('node:assert/strict');
(async()=>{
  const id=`QA${Date.now()}`,created=[];
  try{
    const wav=Buffer.alloc(1644);wav.write('RIFF',0);wav.writeUInt32LE(1636,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(8000,24);wav.writeUInt32LE(16000,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(1600,40);
    for(const [type,bytes]of [['pdf',Buffer.from('%PDF-1.4\n% private upload QA fixture\n%%EOF')],['audio',wav]]){
      const asset=await uploadToCloudinary(bytes,`${id}_${type}`,type,id);created.push(asset);
      assert.equal(asset.type,'authenticated');assert.ok(!asset.secure_url.includes('/s--'));
      const direct=await fetch(asset.secure_url,{method:'HEAD',signal:AbortSignal.timeout(15000)});assert.ok(!direct.ok);
      const original=await media.downloadOriginal(id,asset.secure_url,type);assert.deepEqual(original,bytes);
      console.log(`Actual authenticated ${type} upload: original byte equality, unsigned ${direct.status}`);
    }
  }finally{for(const asset of created)await cloudinary.uploader.destroy(asset.public_id,{resource_type:asset.resource_type,type:'authenticated',invalidate:true});await db.end();}
})().catch(error=>{console.error('Actual private upload check failed:',error.http_code||error.code||'',error.message||error.error?.message);process.exitCode=1;});
