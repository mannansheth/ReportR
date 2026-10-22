const db = require('../config/dbConfig');
const ACTIVE = ['Issue Raised','Verification pending','In Progress'];
let schemaPromise;
function categoryKeys(category) {
  return [...new Set(String(category || '').toLowerCase().split(',').map(value => {
    const clean = value.trim().replace(/[^a-z0-9]+/g,' ');
    if (/pothole|road damage|damaged road/.test(clean)) return 'pothole';
    if (/garbage|waste|litter|rubbish/.test(clean)) return 'garbage';
    if (/drain|sewage|sewer/.test(clean)) return 'drainage';
    if (/street.*light|streetlight/.test(clean)) return 'streetlight';
    if (/water.*leak|leak.*water/.test(clean)) return 'water leak';
    if (/flood|waterlog/.test(clean)) return 'flooding';
    return clean;
  }).filter(Boolean))].sort();
}
// Duplicate detection uses the visible issue labels themselves. Keep this
// separate from categoryKeys(), whose synonym mapping is for prioritization.
function exactIssueKeywords(category) {
  return [...new Set(String(category || '').split(',').map(value =>
    value.trim().toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim().replace(/\s+/g, ' ')
  ).filter(Boolean))];
}
function baselinePriority(issue, description = '', visualSeverity = null) {
  const base = Math.max(30,...categoryKeys(issue).map(key => ({pothole:55,garbage:40,drainage:60,streetlight:45,'water leak':60,flooding:70}[key] || 35)));
  const severity = Number(visualSeverity);
  const adjustment = visualSeverity != null && Number.isFinite(severity) && severity >= 1 && severity <= 10 ? Math.round((severity - 5) * 3) : 0;
  return Math.max(10, Math.min(85,base + adjustment));
}
function priorityScore(baseline, confirmations) { return Math.min(100,Math.round(Number(baseline) + Math.min(40,12*Math.log2(Math.max(1,Number(confirmations)))))); }
function parseLocation(value) { try { return typeof value === 'string' ? JSON.parse(value) : value; } catch (_) { return null; } }
function coordinates(location) {
  const value = parseLocation(location);
  if (!value || value.lat == null || value.lng == null || !Number.isFinite(Number(value.lat)) || !Number.isFinite(Number(value.lng)) || Math.abs(Number(value.lat)) > 90 || Math.abs(Number(value.lng)) > 180) throw Object.assign(new Error('A valid report location is required'),{status:400,code:'INVALID_LOCATION'});
  return {...value,lat:Number(value.lat),lng:Number(value.lng)};
}
function freshLocation(location) {
  const value = coordinates(location);
  const timestamp = typeof value.timestamp === 'number' ? value.timestamp : Date.parse(value.timestamp);
  const age = Date.now()-timestamp;
  if (!Number.isFinite(timestamp) || age > 300000 || age < -30000 || value.accuracy == null || !Number.isFinite(Number(value.accuracy)) || Number(value.accuracy) < 0 || Number(value.accuracy) > 100) throw Object.assign(new Error('Refresh your location. Accuracy must be within 100 metres and the reading within five minutes.'),{status:400,code:'LOCATION_NOT_FRESH'});
  return {...value,timestamp,accuracy:Number(value.accuracy)};
}
function distanceMeters(a,b) {
  const radians = value=>value*Math.PI/180;
  const dlat=radians(Number(b.lat)-Number(a.lat)), dlng=radians(Number(b.lng)-Number(a.lng));
  const term=Math.sin(dlat/2)**2+Math.cos(radians(Number(a.lat)))*Math.cos(radians(Number(b.lat)))*Math.sin(dlng/2)**2;
  return 6371000*2*Math.atan2(Math.sqrt(Math.min(1,term)),Math.sqrt(Math.max(0,1-term)));
}
function ensureSchema() {
  if (!schemaPromise) schemaPromise = (async()=>{
    await db.query(`CREATE TABLE IF NOT EXISTS report_community (Rid VARCHAR(20) PRIMARY KEY, categoryKey VARCHAR(255) NOT NULL, baselinePriority INT NOT NULL, createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)`);
    await db.query(`CREATE TABLE IF NOT EXISTS report_confirmations (Rid VARCHAR(20) NOT NULL, userID INT NOT NULL, latitude DOUBLE NOT NULL, longitude DOUBLE NOT NULL, accuracy DOUBLE NOT NULL, locatedAt DATETIME NOT NULL, createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(Rid,userID))`);
    await db.query(`CREATE TABLE IF NOT EXISTS report_resolution_votes (Rid VARCHAR(20) NOT NULL, userID INT NOT NULL, note VARCHAR(2000) NOT NULL DEFAULT '', imageURL VARCHAR(1000) NULL, photoVerified TINYINT NOT NULL DEFAULT 0, evidenceState VARCHAR(30) NOT NULL DEFAULT 'none', weight INT NOT NULL, latitude DOUBLE NOT NULL, longitude DOUBLE NOT NULL, accuracy DOUBLE NOT NULL, locatedAt DATETIME NOT NULL, createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(Rid,userID))`);
    const [rows] = await db.query('SELECT Rid, issue, description, priority FROM reports');
    for(const row of rows) {
      await db.query('INSERT IGNORE INTO report_community (Rid,categoryKey,baselinePriority) VALUES (?,?,?)',[row.Rid,categoryKeys(row.issue).join(','),baselinePriority(row.issue,row.description,row.priority)]);
      if(Number(row.priority)>=1&&Number(row.priority)<=10)await db.query('UPDATE report_community SET baselinePriority = ? WHERE Rid = ?',[baselinePriority(row.issue,row.description,row.priority),row.Rid]);
    }
  })().catch(error=>{schemaPromise=null;throw error;});
  return schemaPromise;
}
function publicDto(row,userId,confirmations,votes,metadata,nearLocation) {
  const base = metadata?.baselinePriority || baselinePriority(row.issue,row.description);
  const location = parseLocation(row.location);
  const owner = String(row.userID) === String(userId);
  const count = 1+confirmations.filter(v=>String(v.userID)!==String(row.userID)).length;
  return {Rid:row.Rid,issue:row.issue,description:row.description || '',location,imageURL:row.imageURL,status:row.status,createdAt:row.createdAt,resolvedAt:row.resolvedAt,priority:priorityScore(base,count),baselinePriority:base,confirmationCount:count,confirmedByMe:owner || confirmations.some(v=>String(v.userID)===String(userId)),isOwner:owner,distanceMeters:nearLocation&&location?Math.round(distanceMeters(nearLocation,location)):null,resolutionWeight:votes.reduce((sum,v)=>sum+v.weight,0),resolutionVoters:votes.length,resolutionOriginalReporterVoted:votes.some(v=>String(v.userID)===String(row.userID)),resolutionVerifiedPhoto:votes.some(v=>!!v.photoVerified),resolutionVotedByMe:votes.some(v=>String(v.userID)===String(userId)),myEvidenceState:votes.find(v=>String(v.userID)===String(userId))?.evidenceState || null};
}
async function aggregateMany(rows,userId,connection=db,nearLocation=null) {
  if (!rows.length) return [];
  const ids=rows.map(row=>row.Rid);
  const [confirmations]=await connection.query('SELECT Rid,userID FROM report_confirmations WHERE Rid IN (?)',[ids]);
  const [votes]=await connection.query('SELECT Rid,userID,weight,photoVerified,evidenceState FROM report_resolution_votes WHERE Rid IN (?)',[ids]);
  const [metadata]=await connection.query('SELECT Rid,baselinePriority FROM report_community WHERE Rid IN (?)',[ids]);
  const groupedConfirmations=new Map(),groupedVotes=new Map(),groupedMetadata=new Map(metadata.map(row=>[row.Rid,row]));
  for(const row of confirmations){if(!groupedConfirmations.has(row.Rid))groupedConfirmations.set(row.Rid,[]);groupedConfirmations.get(row.Rid).push(row);}
  for(const row of votes){if(!groupedVotes.has(row.Rid))groupedVotes.set(row.Rid,[]);groupedVotes.get(row.Rid).push(row);}
  return rows.map(row=>publicDto(row,userId,groupedConfirmations.get(row.Rid)||[],groupedVotes.get(row.Rid)||[],groupedMetadata.get(row.Rid),nearLocation));
}
async function aggregate(row,userId,connection=db,nearLocation=null) { return (await aggregateMany([row],userId,connection,nearLocation))[0]; }
async function nearbyMatches(category,location,userId,connection=db) {
  const keys=exactIssueKeywords(category);
  const [rows]=await connection.query("SELECT * FROM reports WHERE status IN ('Issue Raised','Verification pending','In Progress')");
  const matches=rows.filter(row=>{const point=parseLocation(row.location);const existingKeys=exactIssueKeywords(row.issue);return point&&keys.length>0&&keys.some(key=>existingKeys.includes(key))&&distanceMeters(location,point)<=100;});
  const reports=await aggregateMany(matches,userId,connection,location);
  return reports.sort((a,b)=>a.distanceMeters-b.distanceMeters);
}
module.exports={ACTIVE,categoryKeys,baselinePriority,priorityScore,parseLocation,coordinates,freshLocation,distanceMeters,ensureSchema,aggregate,aggregateMany,nearbyMatches};
