const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const db=require('../config/dbConfig'),cloudinary=require('../config/cloudinaryConfig'),media=require('../services/privateMedia');
const apply=process.argv.includes('--apply'),directory=path.resolve(__dirname,'../data/private-media-backups'),journalPath=path.join(directory,'migration.json');
async function writeJournal(journal){await fs.mkdir(directory,{recursive:true});await fs.writeFile(journalPath,JSON.stringify(journal,null,2),{mode:0o600});}
(async()=>{
  const [rows]=await db.query('SELECT Rid,audioURL,pdfURL FROM reports');
  let journal=[];try{journal=JSON.parse(await fs.readFile(journalPath,'utf8'));}catch(error){if(error.code!=='ENOENT')throw error;}
  let planned=0,migrated=0,alreadyPrivate=0;
  for(const row of rows)for(const [column,kind]of [['audioURL','audio'],['pdfURL','pdf']]){
    const remote=row[column];if(!remote)continue;
    const asset=media.parseAsset(row.Rid,remote,kind);if(!asset)throw new Error(`Refusing untrusted ${kind} asset for ${row.Rid}`);
    if(asset.type==='authenticated'){const clean=media.unsignedDeliveryUrl(remote);if(apply&&clean!==remote)await db.query(`UPDATE reports SET ${column} = ? WHERE Rid = ? AND ${column} = ?`,[clean,row.Rid,remote]);alreadyPrivate++;continue;}
    planned++;
    if(!apply)continue;
    let entry=journal.find(value=>value.id===row.Rid&&value.column===column&&value.oldUrl===remote);
    if(!entry){entry={id:row.Rid,column,oldUrl:remote,newPublicId:`reportr/reports/${row.Rid}/private_${crypto.randomUUID()}${asset.resourceType==='raw'?'.'+asset.extension:''}`,resourceType:asset.resourceType,state:'planned'};journal.push(entry);await writeJournal(journal);}
    const backup=path.join(directory,`${row.Rid}_${kind}.bin`);
    let before;try{before=await fs.readFile(backup);}catch(error){if(error.code!=='ENOENT')throw error;before=await media.downloadOriginal(row.Rid,remote,kind);if(!before)throw new Error(`Unable to preserve original ${kind} for ${row.Rid}`);await fs.writeFile(backup,before,{mode:0o600,flag:'wx'});}
    let renamed;
    try{renamed=await cloudinary.api.resource(entry.newPublicId,{resource_type:asset.resourceType,type:'authenticated'});}catch(error){if((error.http_code||error.error?.http_code)!==404)throw error;renamed=await cloudinary.uploader.rename(asset.publicId,entry.newPublicId,{resource_type:asset.resourceType,type:asset.type,to_type:'authenticated',invalidate:true,overwrite:false});}
    const newUrl=media.unsignedDeliveryUrl(renamed.secure_url);
    if(!newUrl||!media.parseAsset(row.Rid,newUrl,kind)||media.parseAsset(row.Rid,newUrl,kind).type!=='authenticated')throw new Error('Migration returned unexpected delivery metadata');
    const after=await media.downloadOriginal(row.Rid,newUrl,kind);
    if(!after||!crypto.timingSafeEqual(crypto.createHash('sha256').update(before).digest(),crypto.createHash('sha256').update(after).digest()))throw new Error(`Original integrity check failed for ${row.Rid} ${kind}`);
    const response=await fetch(newUrl,{method:'HEAD',redirect:'error',signal:AbortSignal.timeout(15000)});
    if(response.ok)throw new Error(`Authenticated asset unexpectedly accessible without signature: ${row.Rid} ${kind}`);
    await db.query(`UPDATE reports SET ${column} = ? WHERE Rid = ? AND ${column} = ?`,[newUrl,row.Rid,remote]);
    entry.state='complete';entry.newUrl=newUrl;entry.sha256=crypto.createHash('sha256').update(after).digest('hex');entry.completedAt=new Date().toISOString();await writeJournal(journal);
    const old=await fetch(remote,{method:'HEAD',redirect:'error',signal:AbortSignal.timeout(15000)});
    console.log(`${row.Rid} ${kind}: preserved, authenticated unsigned=${response.status}, old public=${old.status}`);
    if(old.ok){entry.oldCachePending=true;await writeJournal(journal);}
    migrated++;
  }
  console.log(JSON.stringify({mode:apply?'apply':'dry-run',trustedPublicAssets:planned,migrated,alreadyPrivate}));
})().catch(error=>{console.error('Private media migration failed:',error.http_code||error.error?.http_code||error.code||'',error.message||error.error?.message||'Unknown Cloudinary error');process.exitCode=1;}).finally(()=>db.end());
