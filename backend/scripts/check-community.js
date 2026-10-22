const assert=require('node:assert/strict');
let photoState='pending',uploads=0,verificationPause=null,verificationStarted=null;
function stub(path,exports){const id=require.resolve(path);require.cache[id]={id,filename:id,loaded:true,exports};}
stub('../services/IssueVerification',{verifyIssue:async()=>({score:95,priority:6})});
stub('../services/resolutionVerification',{verifyResolution:async()=>{verificationStarted?.();if(verificationPause)await verificationPause;return {verified:photoState==='verified',state:photoState};}});
stub('../services/UploadToCloudinary',{uploadToCloudinary:async()=>{uploads++;return {secure_url:'https://example.invalid/community-fixture.jpg'};}});
stub('../services/firebaseMessaging',{sendNotification:async()=>true});
const app=require('../server'),db=require('../config/dbConfig'),jwt=require('jsonwebtoken'),model=require('../services/communityModel');
(async()=>{
  await model.ensureSchema();
  const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));
  const base=`http://127.0.0.1:${server.address().port}`,prefix=`CT${Date.now()}`,ids=[],users=[],tokens=[];
  const point={lat:1.234567,lng:8.987654};
  const fresh=(changes={})=>({...point,accuracy:10,timestamp:new Date().toISOString(),...changes});
  async function request(path,body,token=tokens[0],method=body===undefined?'GET':'POST'){
    const response=await fetch(base+'/api/reports'+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});return {status:response.status,data:await response.json()};
  }
  async function create(id,index=0,location=point,category='Pothole'){
    ids.push(id);const form=new FormData();for(const [key,value]of Object.entries({reportID:id,category,description:'Dangerous damaged road',location:JSON.stringify(location)}))form.set(key,value);
    form.set('image',new Blob(['fixture-image-content'],{type:'image/jpeg'}),'photo.jpg');
    const response=await fetch(base+'/api/user/submitReport',{method:'POST',headers:{Authorization:`Bearer ${tokens[index]}`},body:form});return {status:response.status,data:await response.json()};
  }
  async function resolve(id,index,photo=false,location=fresh()){
    const form=new FormData();form.set('location',JSON.stringify(location));form.set('note','Repair observed at this location');if(photo)form.set('image',new Blob(['valid-fixture-photo-bytes'],{type:'image/jpeg'}),'evidence.jpg');
    const response=await fetch(base+`/api/reports/${id}/resolution`,{method:'POST',headers:{Authorization:`Bearer ${tokens[index]}`},body:form});return {status:response.status,data:await response.json()};
  }
  try{
    for(let i=0;i<6;i++){const [result]=await db.query("INSERT INTO users (name,number,createdAt,token,role) VALUES (?,?,NOW(),'','Citizen')",['Community fixture '+i,'98888888'+String(i).padStart(2,'0')]);users.push(result.insertId);tokens.push(jwt.sign({userId:String(result.insertId)},process.env.JWT_SECRET));}
    assert.equal((await request('/community',undefined,null)).status,401);
    const concurrent=await Promise.all([create(prefix+'A'),create(prefix+'B',1,{lat:point.lat+.001,lng:point.lng})]);
    assert.deepEqual(concurrent.map(v=>v.status).sort(),[200,409]);
    assert.equal(uploads,1,'duplicate rejected before any cloud upload');
    const winner=concurrent[0].status===200?0:1,owner=winner,other=winner===0?1:0,id=prefix+(winner===0?'A':'B');
    const duplicate=concurrent.find(v=>v.status===409).data;
    assert.equal(duplicate.code,'NEARBY_DUPLICATE');
    assert.equal(duplicate.report.confirmationCount,1);
    const reportPoint=winner===0?point:{lat:point.lat+.001,lng:point.lng};
    const current=()=>fresh(reportPoint);
    const preflight=await request('/nearbyMatches',{category:'Road damage',location:point});assert.equal(preflight.data.reports.some(v=>v.Rid===id),true);
    const novel=await request('/nearbyMatches',{category:'Pothole, Garbage',location:point});assert.equal(novel.data.reports.some(v=>v.Rid===id),false);
    assert.equal((await request(`/${id}/confirm`,{location:current()},tokens[owner])).data.report.confirmationCount,1);
    const repeats=await Promise.all([request(`/${id}/confirm`,{location:current()},tokens[other]),request(`/${id}/confirm`,{location:current()},tokens[other])]);
    assert.ok(repeats.every(v=>v.data.report.confirmationCount===2));
    assert.ok(repeats.some(v=>v.data.alreadyConfirmed));
    assert.equal((await request(`/${id}/confirm`,{location:fresh({lat:point.lat+1})},tokens[2])).status,403);
    assert.equal((await request(`/${id}/confirm`,{location:fresh({timestamp:new Date(Date.now()-3600000).toISOString()})},tokens[2])).status,400);
    assert.equal((await request(`/${id}/confirm`,{location:fresh({accuracy:101})},tokens[2])).status,400);
    const publicReport=(await request('/community/'+id,undefined,tokens[other])).data.report;
    for(const key of ['userID','phone','number','token','audioURL','pdfURL','name','resolvedBy'])assert.equal(publicReport[key],undefined,key);
    assert.equal(publicReport.confirmedByMe,true);assert.equal(publicReport.isOwner,false);assert.ok(publicReport.priority>publicReport.baselinePriority);
    const markers=await request('/getAllReports');assert.ok(markers.data.every(v=>v.userID===undefined));
    assert.equal((await resolve(id,owner,false,current())).data.resolution.weight,3);
    const pending=await resolve(id,other,true,current());assert.equal(pending.data.resolution.weight,4);assert.equal(pending.data.report.status,'Issue Raised');assert.equal(pending.data.report.myEvidenceState,'pending');
    assert.equal((await resolve(id,other,false,current())).data.alreadyVoted,true);
    assert.equal((await resolve(id,2,false,fresh({lat:point.lat+1}))).status,403);
    const resolved=await resolve(id,2,false,current());assert.equal(resolved.data.report.status,'Resolved');assert.equal(resolved.data.resolution.weight,5);assert.equal(resolved.data.resolution.voters,3);
    const photoId=prefix+'C';assert.equal((await create(photoId,0)).status,200);
    photoState='verified';
    let releaseVerification,started;
    verificationPause=new Promise(resolve=>{releaseVerification=resolve;});
    const startedPromise=new Promise(resolve=>{verificationStarted=resolve;});
    const slowResolution=resolve(photoId,0,true);
    await startedPromise;
    const duringVerification=await request(`/${photoId}/confirm`,{location:fresh()},tokens[1]);
    assert.equal(duringVerification.status,200,'AI network request must not hold the report row lock');
    releaseVerification();verificationPause=null;verificationStarted=null;
    const photoResolved=await slowResolution;assert.equal(photoResolved.data.report.status,'Resolved');assert.equal(photoResolved.data.resolution.weight,6);assert.equal(photoResolved.data.resolution.voters,1);
    const upgradeId=prefix+'D';assert.equal((await create(upgradeId,0)).status,200);
    photoState='not_verified';const notVerified=await resolve(upgradeId,0,true);assert.equal(notVerified.data.report.resolutionVerifiedPhoto,false);assert.equal(notVerified.data.resolution.weight,3);assert.notEqual(notVerified.data.report.status,'Resolved');
    photoState='verified';const upgraded=await resolve(upgradeId,0,true);assert.equal(upgraded.data.report.status,'Resolved');assert.equal(upgraded.data.resolution.voters,1);assert.equal(upgraded.data.resolution.weight,6);
    const analytics=(await request('/analytics?scope=community')).data;assert.ok(analytics.total>=3);assert.ok(analytics.resolved>=3);assert.ok(analytics.resolvedWithEvidence>=2);assert.ok(analytics.byCategory.length>0);
    const mine=(await request('/analytics?scope=mine',undefined,tokens[5])).data;assert.equal(mine.total,0);
    const feed=(await request('/community?limit=1&lat=1.234567&lng=8.987654&sort=nearby')).data;assert.equal(feed.reports.length,1);assert.ok(feed.total>=3);assert.ok(feed.hasMore);
    assert.ok(model.distanceMeters(point,{lat:point.lat+.001,lng:point.lng})>100);
    assert.equal(model.priorityScore(80,10000),100);
    assert.ok(model.baselinePriority('Pothole','',9)>model.baselinePriority('Pothole','',2));
    assert.equal(model.baselinePriority('Pothole','description text',7),model.baselinePriority('Pothole','',7));
    console.log('PASS community: concurrent nearby dedup before cloud uploads, canonical synonyms and novel types, unique owner/repeat confirmations, fresh GPS/radius enforcement, private fields, weighted evidence verification/pending/upgrade/replay, resolution transitions, global/mine statistics, pagination and priority cap');
  }finally{
    for(const id of ids)for(const table of ['report_resolution_votes','report_confirmations','report_community','report_status_history','reports'])await db.query(`DELETE FROM ${table} WHERE Rid = ?`,[id]);
    for(const id of users)await db.query('DELETE FROM users WHERE id = ?',[id]);
    await new Promise(r=>server.close(r));await db.end();
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
