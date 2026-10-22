const express=require('express');
const router=express.Router();
const db=require('../config/dbConfig');
const {requireAuth}=require('./authMiddleware');
const upload=require('../config/multerConfig');
const model=require('./communityModel');
const {verifyResolution}=require('./resolutionVerification');
const {uploadToCloudinary}=require('./UploadToCloudinary');
const ready=async(req,res,next)=>{try{await model.ensureSchema();next();}catch(error){next(error);}};
const failed=(res,error)=>res.status(error.status||503).json({success:false,code:error.code||'COMMUNITY_UNAVAILABLE',message:error.status?error.message:'Community reports are temporarily unavailable. Try again.'});
router.post('/nearbyMatches',requireAuth,ready,async(req,res)=>{try{const location=model.coordinates(req.body.location);res.json({reports:await model.nearbyMatches(req.body.category,location,req.userId)});}catch(error){failed(res,error);}});
router.get('/community',requireAuth,ready,async(req,res)=>{try{
  let location=null;
  if(req.query.lat!=null||req.query.lng!=null) location=model.coordinates({lat:req.query.lat,lng:req.query.lng});
  const page=Math.max(1,Math.min(100000,parseInt(req.query.page)||1)),limit=Math.max(1,Math.min(50,parseInt(req.query.limit)||20));
  const [rows]=await db.query("SELECT * FROM reports WHERE status <> 'Invalid Report' OR status IS NULL");
  let reports=await model.aggregateMany(rows,req.userId,db,location);
  if(req.query.status) reports=reports.filter(row=>row.status===req.query.status);
  if(req.query.category) reports=reports.filter(row=>model.categoryKeys(req.query.category).every(key=>model.categoryKeys(row.issue).includes(key)));
  reports.sort((a,b)=> req.query.sort==='nearby'&&location ? a.distanceMeters-b.distanceMeters||b.priority-a.priority : b.priority-a.priority||(location?a.distanceMeters-b.distanceMeters:0)||new Date(b.createdAt)-new Date(a.createdAt));
  res.json({reports:reports.slice((page-1)*limit,page*limit),total:reports.length,page,hasMore:reports.length>page*limit});
}catch(error){failed(res,error);}});
router.get('/community/:id',requireAuth,ready,async(req,res)=>{try{const [rows]=await db.query('SELECT * FROM reports WHERE Rid = ?',[req.params.id]);if(!rows.length||(rows[0].status==='Invalid Report'&&String(rows[0].userID)!==req.userId))return res.status(404).json({success:false,message:'Report not found'});res.json({report:await model.aggregate(rows[0],req.userId)});}catch(error){failed(res,error);}});
router.post('/:id/confirm',requireAuth,ready,async(req,res)=>{
  let connection;
  try {
    const location=model.freshLocation(req.body.location);
    connection=await db.getConnection();await connection.beginTransaction();
    const [rows]=await connection.query('SELECT * FROM reports WHERE Rid = ? FOR UPDATE',[req.params.id]);
    if(!rows.length)throw Object.assign(new Error('Report not found'),{status:404});
    const report=rows[0];
    if(!model.ACTIVE.includes(report.status))throw Object.assign(new Error('Only active reports can be confirmed'),{status:409});
    if(model.distanceMeters(location,model.coordinates(report.location))>500)throw Object.assign(new Error('Move within 500 metres to confirm this report'),{status:403,code:'OUTSIDE_CONFIRM_RADIUS'});
    const owner=String(report.userID)===req.userId;
    let inserted=0;
    if(!owner){const [result]=await connection.query('INSERT IGNORE INTO report_confirmations (Rid,userID,latitude,longitude,accuracy,locatedAt) VALUES (?,?,?,?,?,?)',[report.Rid,req.userId,location.lat,location.lng,location.accuracy,new Date(location.timestamp)]);inserted=result.affectedRows;}
    const dto=await model.aggregate(report,req.userId,connection,location);
    await connection.query('UPDATE reports SET priority = ? WHERE Rid = ?',[dto.priority,report.Rid]);
    await connection.commit();res.json({success:true,alreadyConfirmed:owner||!inserted,report:dto});
  }catch(error){if(connection)await connection.rollback();failed(res,error);}finally{connection?.release();}
});
router.post('/:id/resolution',requireAuth,ready,upload.single('image'),async(req,res)=>{
  let connection,uploadedAsset,keepAsset=false;
  try {
    const location=model.freshLocation(req.body.location),note=String(req.body.note||'').trim();
    if(note.length>2000)throw Object.assign(new Error('Keep the note within 2000 characters'),{status:400});
    if(req.file&&(!['image/jpeg','image/png','image/webp'].includes(req.file.mimetype)||req.file.buffer.length<16))throw Object.assign(new Error('Use a JPG, PNG or WebP evidence photo'),{status:400});
    // Network work deliberately happens before taking a MySQL connection/row lock.
    const [initialRows]=await db.query('SELECT * FROM reports WHERE Rid = ?',[req.params.id]);
    if(!initialRows.length)throw Object.assign(new Error('Report not found'),{status:404});
    const initial=initialRows[0];
    if(initial.status==='Invalid Report')throw Object.assign(new Error('Invalid reports cannot receive resolution votes'),{status:409});
    if(model.distanceMeters(location,model.coordinates(initial.location))>200)throw Object.assign(new Error('Move within 200 metres to submit resolution evidence'),{status:403,code:'OUTSIDE_RESOLUTION_RADIUS'});
    const [initialVotes]=await db.query('SELECT * FROM report_resolution_votes WHERE Rid = ? AND userID = ?',[initial.Rid,req.userId]);
    if(initial.status==='Resolved'||(initialVotes.length&&(!req.file||initialVotes[0].photoVerified))){const dto=await model.aggregate(initial,req.userId,db,location);return res.json({success:true,alreadyVoted:!!initialVotes.length,report:dto,resolution:summary(dto)});}
    let verification={verified:false,state:'none'};
    if(req.file){verification=await verifyResolution(req.file.buffer,req.file.mimetype,initial.issue,initial.imageURL);uploadedAsset=await uploadToCloudinary(req.file.buffer,`${initial.Rid}_resolution_${req.userId}_${require('crypto').randomBytes(4).toString('hex')}`,'image',initial.Rid);}
    // Recheck freshness, status, proximity, and uniqueness after network latency.
    model.freshLocation(location);
    connection=await db.getConnection();await connection.beginTransaction();
    const [rows]=await connection.query('SELECT * FROM reports WHERE Rid = ? FOR UPDATE',[initial.Rid]);
    if(!rows.length)throw Object.assign(new Error('Report not found'),{status:404});
    const report=rows[0];
    if(report.status==='Invalid Report')throw Object.assign(new Error('Invalid reports cannot receive resolution votes'),{status:409});
    if(model.distanceMeters(location,model.coordinates(report.location))>200)throw Object.assign(new Error('Move within 200 metres to submit resolution evidence'),{status:403,code:'OUTSIDE_RESOLUTION_RADIUS'});
    const [existing]=await connection.query('SELECT * FROM report_resolution_votes WHERE Rid = ? AND userID = ?',[report.Rid,req.userId]);
    if(report.status==='Resolved'||(existing.length&&(!req.file||existing[0].photoVerified))){const dto=await model.aggregate(report,req.userId,connection,location);await connection.commit();return res.json({success:true,alreadyVoted:!!existing.length,report:dto,resolution:summary(dto)});}
    const isOwner=String(report.userID)===req.userId;
    const weight=(isOwner?3:1)+(verification.verified?3:0);
    if(existing.length)await connection.query('DELETE FROM report_resolution_votes WHERE Rid = ? AND userID = ?',[report.Rid,req.userId]);
    await connection.query('INSERT INTO report_resolution_votes (Rid,userID,note,imageURL,photoVerified,evidenceState,weight,latitude,longitude,accuracy,locatedAt) VALUES (?,?,?,?,?,?,?,?,?,?,?)',[report.Rid,req.userId,note,uploadedAsset?.secure_url||null,verification.verified?1:0,verification.state,weight,location.lat,location.lng,location.accuracy,new Date(location.timestamp)]);
    let dto=await model.aggregate(report,req.userId,connection,location);
    const resolve=(dto.resolutionOriginalReporterVoted&&dto.resolutionVerifiedPhoto)||(dto.resolutionWeight>=5&&dto.resolutionVoters>=2);
    if(resolve){await connection.query('UPDATE reports SET status = ?, resolvedAt = NOW(), resolutionNote = ?, resolvedBy = ? WHERE Rid = ?',['Resolved',note||'Resolved through nearby community evidence',req.userId,report.Rid]);await connection.query('INSERT INTO report_status_history (Rid,previousStatus,newStatus,actorUserID,source) VALUES (?,?,?,?,?)',[report.Rid,report.status,'Resolved',req.userId,'community']);report.status='Resolved';report.resolvedAt=new Date();dto=await model.aggregate(report,req.userId,connection,location);}
    await connection.commit();keepAsset=true;res.json({success:true,alreadyVoted:false,report:dto,resolution:summary(dto)});
  }catch(error){if(connection)await connection.rollback();failed(res,error);}finally{
    connection?.release();
    if(uploadedAsset?.public_id&&!keepAsset)await require('../config/cloudinaryConfig').uploader.destroy(uploadedAsset.public_id,{resource_type:uploadedAsset.resource_type||'image',type:uploadedAsset.type||'upload'}).catch(()=>{});
  }
});
function summary(dto){return {weight:dto.resolutionWeight,voters:dto.resolutionVoters,originalReporterVoted:dto.resolutionOriginalReporterVoted,verifiedPhoto:dto.resolutionVerifiedPhoto,requiredWeight:5,requiredVoters:2};}
router.get('/analytics',requireAuth,ready,async(req,res)=>{try{
  const scope=req.query.scope==='mine'?'mine':'community';
  const [rows]=await db.query(scope==='mine'?'SELECT * FROM reports WHERE userID = ?':'SELECT * FROM reports',scope==='mine'?[req.userId]:[]);
  const reports=await model.aggregateMany(rows,req.userId);
  const status={},categories={},months={},priorities={};
  for(const report of reports){status[report.status||'Unknown']=(status[report.status||'Unknown']||0)+1;for(const category of model.categoryKeys(report.issue))categories[category]=(categories[category]||0)+1;const month=new Date(report.createdAt).toISOString().slice(0,7);months[month]||={month,count:0,resolved:0};months[month].count++;if(report.status==='Resolved')months[month].resolved++;const band=report.priority>=75?'High':report.priority>=45?'Medium':'Low';priorities[band]=(priorities[band]||0)+1;}
  const resolved=reports.filter(r=>r.status==='Resolved');
  const durations=rows.filter(r=>r.status==='Resolved'&&r.resolvedAt&&r.createdAt).map(r=>Math.max(0,(new Date(r.resolvedAt)-new Date(r.createdAt))/3600000));
  res.json({scope,total:reports.length,resolved:resolved.length,active:reports.filter(r=>model.ACTIVE.includes(r.status)).length,pending:status['Verification pending']||0,invalid:status['Invalid Report']||0,resolutionRate:reports.length?resolved.length/reports.length*100:0,confirmationCount:reports.reduce((sum,r)=>sum+r.confirmationCount,0),resolvedWithEvidence:resolved.filter(r=>r.resolutionVerifiedPhoto).length,byStatus:Object.entries(status).map(([status,count])=>({status,count})),byCategory:Object.entries(categories).map(([category,count])=>({category,count})),byPriority:Object.entries(priorities).map(([priority,count])=>({priority,count})),monthly:Object.values(months).sort((a,b)=>a.month.localeCompare(b.month)),averageResolutionHours:durations.length?durations.reduce((a,b)=>a+b,0)/durations.length:null});
}catch(error){failed(res,error);}});
module.exports=router;
