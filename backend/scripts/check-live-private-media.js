const app=require('../server'),db=require('../config/dbConfig'),jwt=require('jsonwebtoken'),assert=require('node:assert/strict'),media=require('../services/privateMedia');
(async()=>{
  const server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));const base=`http://127.0.0.1:${server.address().port}`;
  try{
    const [rows]=await db.query('SELECT Rid,userID,audioURL,pdfURL FROM reports');let checked=0,denied=0,ownerAudio=false,ownerPdf=false;
    for(const row of rows)for(const [column,kind]of [['audioURL','audio'],['pdfURL','pdf']]){
      if(!row[column])continue;const asset=media.parseAsset(row.Rid,row[column],kind);assert.ok(asset&&asset.type==='authenticated');assert.ok(!new URL(row[column]).pathname.includes('/s--'));
      const unauthenticated=await fetch(row[column],{method:'HEAD',redirect:'error',signal:AbortSignal.timeout(15000)});assert.ok(!unauthenticated.ok);checked++;denied++;
      if(row.userID&&((kind==='audio'&&!ownerAudio)||(kind==='pdf'&&!ownerPdf))){
        const token=jwt.sign({userId:String(row.userID)},process.env.JWT_SECRET);
        const response=await fetch(`${base}/api/reports/${row.Rid}/${kind}`,{headers:{Authorization:`Bearer ${token}`,...(kind==='audio'?{Range:'bytes=0-15'}:{})},signal:AbortSignal.timeout(45000)});
        assert.equal(response.status,kind==='audio'?206:200);const bytes=Buffer.from(await response.arrayBuffer());assert.ok(bytes.length>0);if(kind==='pdf')assert.equal(bytes.subarray(0,5).toString(),'%PDF-');
        if(kind==='audio')ownerAudio=true;else ownerPdf=true;
        assert.equal((await fetch(`${base}/api/reports/${row.Rid}/${kind}`)).status,401);
        const [others]=await db.query('SELECT id FROM users WHERE id <> ? LIMIT 1',[row.userID]);if(others.length){const otherToken=jwt.sign({userId:String(others[0].id)},process.env.JWT_SECRET);assert.equal((await fetch(`${base}/api/reports/${row.Rid}/${kind}`,{headers:{Authorization:`Bearer ${otherToken}`}})).status,404);}
      }
    }
    console.log(JSON.stringify({privateAssetsChecked:checked,unsignedDirectDenied:denied,actualOwnerAudioProxy:ownerAudio,actualOwnerPdfProxy:ownerPdf,anonymousDenied:true,otherUserDenied:true}));
  }finally{await new Promise(resolve=>server.close(resolve));await db.end();}
})().catch(error=>{console.error('Live private-media check failed:',error.code||error.name,error.message);process.exitCode=1;});
