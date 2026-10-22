const assert=require('node:assert/strict');
const app=require('../server'),db=require('../config/dbConfig'),jwt=require('jsonwebtoken'),cloudinary=require('../config/cloudinaryConfig'),media=require('../services/privateMedia');
(async()=>{
  const users=[],id=`PM${Date.now()}`,originalDownload=media.downloadOriginal,originalUpload=cloudinary.uploader.upload_stream;
  const server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));
  const base=`http://127.0.0.1:${server.address().port}`,bytes=Buffer.from('0123456789audio');
  try{
    const tokens=[];for(const role of ['Citizen','Citizen','Authority']){const [user]=await db.query("INSERT INTO users(name,number,createdAt,token,role) VALUES('Private media fixture','9777777700',NOW(),'',?)",[role]);users.push(user.insertId);tokens.push(jwt.sign({userId:String(user.insertId)},process.env.JWT_SECRET));}
    const url=`https://res.cloudinary.com/${cloudinary.config().cloud_name}/video/authenticated/v1/reportr/reports/${id}/sound.m4a`;
    await db.query("INSERT INTO reports(Rid,userID,issue,description,location,createdAt,status,audioURL) VALUES(?,?,'Pothole','','{\"lat\":1,\"lng\":1}',NOW(),'Issue Raised',?)",[id,users[0],url]);
    media.downloadOriginal=async(reportId,remote,kind)=>{assert.equal(reportId,id);assert.equal(remote,url);assert.equal(kind,'audio');return bytes;};
    const get=(token,range)=>fetch(base+`/api/reports/${id}/audio`,{headers:{...(token?{Authorization:`Bearer ${token}`}:{}) ,...(range?{Range:range}:{})}});
    assert.equal((await get()).status,401);assert.equal((await get(tokens[1])).status,404);
    const owner=await get(tokens[0]);assert.equal(owner.status,200);assert.equal(owner.headers.get('content-type'),'audio/mp4');assert.deepEqual(Buffer.from(await owner.arrayBuffer()),bytes);
    assert.equal((await get(tokens[2])).status,200);
    const partial=await get(tokens[0],'bytes=2-5');assert.equal(partial.status,206);assert.equal(partial.headers.get('content-range'),`bytes 2-5/${bytes.length}`);assert.equal(await partial.text(),'2345');
    assert.equal((await get(tokens[0],'bytes=99999-')).status,416);
    assert.equal(media.parseAsset(id,url,'audio').type,'authenticated');assert.equal(media.parseAsset(id,url.replace('res.cloudinary.com','evil.invalid'),'audio'),null);
    assert.equal(media.parseAsset(id,url.replace(`/reports/${id}/`,'/reports/other/'),'audio'),null);
    for(const type of ['private','authenticated','upload']){const pdf=`https://res.cloudinary.com/${cloudinary.config().cloud_name}/raw/${type}/v1/reportr/reports/${id}/document.pdf`;assert.ok(require('../services/reportPdfStorage').originalDownloadUrl(id,pdf));}
    const uploads=[];cloudinary.uploader.upload_stream=(options,callback)=>({end:()=>{uploads.push(options);callback(null,{secure_url:'https://res.cloudinary.com/fixture/video/authenticated/s--signature--/v1/sound.m4a'});}});
    const {uploadToCloudinary}=require('../services/UploadToCloudinary');
    for(const type of ['image','audio','pdf'])await uploadToCloudinary(Buffer.from('fixture'),id+'_'+type,type,id);
    assert.equal(uploads[0].type,'upload');assert.equal(uploads[1].type,'authenticated');assert.equal(uploads[1].resource_type,'video');assert.equal(uploads[2].type,'authenticated');assert.equal(uploads[2].resource_type,'raw');assert.ok(uploads[2].public_id.endsWith('.pdf'));
    console.log('PASS private media: authenticated audio/PDF uploads, trusted signed originals across delivery types, owner/authority authorization, other-user denial, accurate MIME and byte-range responses');
  }finally{media.downloadOriginal=originalDownload;cloudinary.uploader.upload_stream=originalUpload;await db.query('DELETE FROM reports WHERE Rid = ?',[id]);for(const user of users)await db.query('DELETE FROM users WHERE id = ?',[user]);await new Promise(resolve=>server.close(resolve));await db.end();}
})().catch(error=>{console.error(error);process.exitCode=1;});
