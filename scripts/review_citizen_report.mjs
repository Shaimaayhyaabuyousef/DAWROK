import {initializeApp,cert} from 'firebase-admin/app';
import {getFirestore,FieldValue} from 'firebase-admin/firestore';
import {readFileSync} from 'node:fs';
// Trusted admin only. Explicit credential file prevents metadata credential probing.
const [reportId,decision,response]=process.argv.slice(2);
const key=process.env.GOOGLE_APPLICATION_CREDENTIALS;
if(!key||!reportId||!['restore','retain'].includes(decision)||!response?.trim())throw Error('Set GOOGLE_APPLICATION_CREDENTIALS, then: node scripts/review_citizen_report.mjs <reportId> <restore|retain> <response>');
initializeApp({credential:cert(JSON.parse(readFileSync(key,'utf8')))});
const db=getFirestore(),ref=db.doc(`reports/${reportId}`);
await db.runTransaction(async tx=>{
 const report=await tx.get(ref);if(!report.exists||report.data().status!=='open')throw Error('Report is missing or already resolved.');
 const uid=report.data().uid,account=db.doc(`citizen_accounts/${uid}`);const a=await tx.get(account);
 if(decision==='restore'){if(!a.exists)throw Error('No restricted account found.');tx.update(account,{streak:0,suspendedAt:null,reviewRequired:false,updatedAt:FieldValue.serverTimestamp()});}
 tx.update(ref,{status:'resolved',response:response.trim(),decision,reviewedAt:FieldValue.serverTimestamp()});
 tx.create(account.collection('events').doc(`review_${reportId}`),{type:'review',bookingId:'',delta:0,read:false,createdAt:FieldValue.serverTimestamp(),message:response.trim(),restored:decision==='restore'});
});
console.log('Report resolved and citizen notified.');
