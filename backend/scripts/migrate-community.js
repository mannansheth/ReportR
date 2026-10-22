const db=require('../config/dbConfig');
require('../services/communityModel').ensureSchema().then(()=>console.log('Community schema migrated without replacing existing reports')).catch(error=>{console.error(error.code || error.message);process.exitCode=1;}).finally(()=>db.end());
