const cloudinary=require('../config/cloudinaryConfig');
const MAX_MEDIA_BYTES=25*1024*1024;
function parseAsset(id,remoteUrl,kind){
  if(!/^[A-Za-z0-9_-]{1,80}$/.test(String(id))||!remoteUrl)return null;
  try{
    const url=new URL(remoteUrl),parts=url.pathname.split('/').filter(Boolean).map(decodeURIComponent);
    if(url.protocol!=='https:'||url.hostname!=='res.cloudinary.com'||url.port||url.username||url.password||parts[0]!==cloudinary.config().cloud_name||!['upload','private','authenticated'].includes(parts[2]))return null;
    const resourceType=parts[1],type=parts[2];
    if(kind==='pdf'&&!['image','raw'].includes(resourceType))return null;
    if(kind==='audio'&&resourceType!=='video')return null;
    const path=parts.slice(3);if(/^s--[A-Za-z0-9_-]+--$/.test(path[0]))path.shift();if(/^v\d+$/.test(path[0]))path.shift();
    const assetPath=path.join('/'),extension=assetPath.split('.').pop().toLowerCase();
    if(!assetPath.startsWith(`reportr/reports/${id}/`)||assetPath.includes('..')||assetPath.includes('\\'))return null;
    if(kind==='pdf'&&extension!=='pdf')return null;
    if(kind==='audio'&&!['m4a','mp3','wav','aac','ogg','webm','mp4','flac'].includes(extension))return null;
    const publicId=resourceType==='raw'?assetPath:assetPath.slice(0,-extension.length-1);
    return {resourceType,type,publicId,extension,assetPath};
  }catch(_){return null;}
}
function unsignedDeliveryUrl(value){const url=new URL(value);url.pathname=url.pathname.replace(/\/s--[A-Za-z0-9_-]+--\//,'/');return url.toString();}
function signedOriginal(id,remoteUrl,kind){const asset=parseAsset(id,remoteUrl,kind);return asset?cloudinary.utils.private_download_url(asset.publicId,asset.resourceType==='raw'?undefined:asset.extension,{resource_type:asset.resourceType,type:asset.type,expires_at:Math.floor(Date.now()/1000)+60}):null;}
async function downloadOriginal(id,remoteUrl,kind){
  const signed=signedOriginal(id,remoteUrl,kind);if(!signed)return null;
  const response=await fetch(signed,{redirect:'error',signal:AbortSignal.timeout(30000)});
  if(!response.ok||Number(response.headers.get('content-length')||0)>MAX_MEDIA_BYTES)return null;
  const chunks=[];let total=0;
  for await(const chunk of response.body){total+=chunk.length;if(total>MAX_MEDIA_BYTES)throw new Error('Private media exceeds size limit');chunks.push(Buffer.from(chunk));}
  return total?Buffer.concat(chunks):null;
}
function audioMime(extension){return ({m4a:'audio/mp4',mp4:'audio/mp4',mp3:'audio/mpeg',wav:'audio/wav',aac:'audio/aac',ogg:'audio/ogg',webm:'audio/webm',flac:'audio/flac'})[extension]||'application/octet-stream';}
module.exports={unsignedDeliveryUrl,parseAsset,signedOriginal,downloadOriginal,audioMime,MAX_MEDIA_BYTES};
