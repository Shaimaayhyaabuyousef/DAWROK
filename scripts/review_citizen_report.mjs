import {initializeApp,cert} from 'firebase-admin/app';
import {getFirestore,FieldValue} from 'firebase-admin/firestore';
import {readFileSync} from 'node:fs';
// Trusted admin only. Explicit credentials prevent metadata credential probing.
// resolve: reply to any report. restore/retain: citizen booking-restriction review.
const [reportId,decision,response]=process.argv.slice(2);
const key=process.env.GOOGLE_APPLICATION_CREDENTIALS;
if(!key||!reportId||!['resolve','restore','retain'].includes(decision)||!response?.trim()||response.trim().length>2000)throw Error('Set GOOGLE_APPLICATION_CREDENTIALS, then: node scripts/review_citizen_report.mjs <reportId> <resolve|restore|retain> <response, max 2000 characters>');
initializeApp({credential:cert(JSON.parse(readFileSync(key,'utf8')))});
const db=getFirestore(),ref=db.doc(`reports/${reportId}`);
await db.runTransaction(async tx=>{
 const report=await tx.get(ref);if(!report.exists||report.data().status!=='open')throw Error('Report is missing or already resolved.');
 const uid=report.data().uid;
 const profile=await tx.get(db.doc(`users/${uid}`));
 const role=report.data().reporterRole??profile.data()?.role;
 if(decision!=='resolve'&&role!=='citizen')throw Error('Booking restriction review is only available for citizens. Use resolve for other accounts.');
 const account=db.doc(`citizen_accounts/${uid}`);
 if(decision==='restore'){
  const a=await tx.get(account);if(!a.exists)throw Error('No restricted account found.');
  tx.update(account,{streak:0,suspendedAt:null,reviewRequired:false,updatedAt:FieldValue.serverTimestamp()});
 }
 tx.update(ref,{status:'resolved',response:response.trim(),decision,reviewedAt:FieldValue.serverTimestamp()});
 const events=role==='citizen'?account.collection('events'):db.doc(`users/${uid}`).collection('notifications');
 tx.create(events.doc(`review_${reportId}`),{type:'review',reportId,bookingId:'',delta:0,read:false,createdAt:FieldValue.serverTimestamp(),message:response.trim(),restored:decision==='restore'});
});
console.log('Report resolved and account notified.');
