require('../config/dbConfig');
const db=require('../config/dbConfig'),assert=require('node:assert/strict');
const {verifyResolution,originalPhoto}=require('../services/resolutionVerification');
(async()=>{
  const originalFetch=global.fetch,oldKey=process.env.GEMINI_API_KEY,oldCloud=process.env.CLOUDINARY_CLOUD_NAME;
  process.env.GEMINI_API_KEY='test-only-no-network';process.env.CLOUDINARY_CLOUD_NAME='qa-cloud';
  let verdict={sameScene:true,allIssuesResolved:true,confidence:90},modelCalls=0;
  global.fetch=async(url,options)=>{
    if(String(url).startsWith('https://res.cloudinary.com/')){assert.equal(options.redirect,'error');return new Response(Buffer.from('original-image-fixture'),{status:200,headers:{'Content-Type':'image/jpeg'}});}
    modelCalls++;const request=JSON.parse(options.body);const photos=request.contents[0].parts.filter(part=>part.inlineData);assert.equal(photos.length,2);assert.notEqual(photos[0].inlineData.data,photos[1].inlineData.data);
    return new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify(verdict)}]}}]}),{status:200});
  };
  const original='https://res.cloudinary.com/qa-cloud/image/upload/v1/reportr/reports/qa/original.jpg';
  try{
    assert.equal((await verifyResolution(Buffer.from('new-image'),'image/jpeg','Pothole, Garbage',original)).verified,true);
    verdict={sameScene:false,allIssuesResolved:true,confidence:99};assert.equal((await verifyResolution(Buffer.from('new-image'),'image/jpeg','Pothole',original)).verified,false);
    verdict={sameScene:true,allIssuesResolved:false,confidence:99};assert.equal((await verifyResolution(Buffer.from('new-image'),'image/jpeg','Pothole, Garbage',original)).verified,false);
    const previousCalls=modelCalls;
    assert.equal((await verifyResolution(Buffer.from('new-image'),'image/jpeg','Pothole','http://127.0.0.1/private')).state,'pending');
    assert.equal(modelCalls,previousCalls);
    await assert.rejects(()=>originalPhoto('https://res.cloudinary.com/other/image/upload/reportr/reports/x.jpg'));
    global.fetch=async()=>new Response(Buffer.alloc(1),{headers:{'Content-Type':'image/jpeg','Content-Length':'999999999'}});
    assert.equal((await verifyResolution(Buffer.from('new-image'),'image/jpeg','Pothole',original)).state,'pending');
    console.log('PASS resolution verification: trusted bounded original download, two-image same-scene/all-issue comparison, unrelated/unrepaired rejection, unavailable original pending, oversized image and SSRF protection');
  }finally{global.fetch=originalFetch;if(oldKey===undefined)delete process.env.GEMINI_API_KEY;else process.env.GEMINI_API_KEY=oldKey;if(oldCloud===undefined)delete process.env.CLOUDINARY_CLOUD_NAME;else process.env.CLOUDINARY_CLOUD_NAME=oldCloud;await db.end();}
})().catch(error=>{console.error(error);process.exitCode=1;});
