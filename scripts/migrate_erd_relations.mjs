import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {initializeApp,cert} from 'firebase-admin/app';
import {getFirestore,FieldValue} from 'firebase-admin/firestore';

// Read-only by default. No account, password, booking order or balance is changed.
const apply=process.argv.includes('--apply');
const emulator=!!process.env.FIRESTORE_EMULATOR_HOST;
const projectId=emulator?'demo-dawrok':'dawrok-f908e';
const keyPath=process.env.GOOGLE_APPLICATION_CREDENTIALS;
if(!emulator&&!keyPath)throw Error('Set GOOGLE_APPLICATION_CREDENTIALS to a private service-account file. No changes were made.');
const key=emulator?null:JSON.parse(readFileSync(keyPath,'utf8'));
if(key&&key.project_id!==projectId)throw Error('The credential must belong to dawrok-f908e.');
initializeApp({projectId,...(key?{credential:cert(key)}:{})});
const db=getFirestore();
const plans=[],issues=[];
let counters=0;
for(const f of (await db.collection('facilities').get()).docs){
 for(const q of (await f.ref.collection('queues').get()).docs){
  const row=q.data(),name=row.service?.trim(),count=row.windowCount??1;
  if(!name||!Number.isInteger(count)||count<0||count>20){issues.push({path:q.ref.path,issue:'invalid service or window count'});continue;}
  const serviceId=createHash('sha256').update(name.toLowerCase()).digest('hex');
  const serviceRef=f.ref.collection('services').doc(serviceId),service=await serviceRef.get();
  if(service.exists&&(service.data().name!==name||service.data().isActive!==true)){
   issues.push({path:q.ref.path,issue:'catalog conflicts with saved queue service'});continue;
  }
  for(let w=1;w<=count;w++){
   const c=await f.ref.collection('counters').doc(`${q.id}_${w}`).get();
   if(c.exists&&(c.data().queueId!==q.id||c.data().windowNumber!==w))issues.push({path:c.ref.path,issue:'counter reference conflict'});
  }
  plans.push({queue:q.ref,facility:f.ref,serviceRef,serviceId,name,count});counters+=count;
 }
}
// Audit, but do not impose a new registration requirement or expose raw values.
const duplicateCounts=async(collection,field)=>{
 const seen=new Map();let duplicates=0;
 for(const d of (await db.collection(collection).get()).docs){
  const value=d.data()[field]?.toString().trim();if(!value)continue;
  if(seen.has(value))duplicates++;else seen.set(value,d.id);
 }
 return duplicates;
};
const audit={queues:plans.length,counters,duplicateNationalIds:await duplicateCounts('citizen_identity','nationalId'),
 duplicateCitizenPhones:await duplicateCounts('users','phone'),issues,mode:apply?'apply':'dry-run'};
console.log(JSON.stringify(audit,null,2));
if(issues.length)throw Error('Resolve the reported relation conflicts before applying. No writes were made.');
if(!apply){console.log('Dry run only. Re-run with --apply after reviewing the result.');process.exit(0);}
let changed=0;
for(const p of plans){
 await db.runTransaction(async tx=>{
  const q=await tx.get(p.queue),service=await tx.get(p.serviceRef);
  if(q.data()?.service!==p.name||(q.data()?.windowCount??1)!==p.count)throw Error('Queue changed during migration; rerun the dry run.');
  const cs=[];for(let w=1;w<=p.count;w++)cs.push(await tx.get(p.facility.collection('counters').doc(`${p.queue.id}_${w}`)));
  if(service.exists&&(service.data().name!==p.name||service.data().isActive!==true))throw Error('Service changed during migration.');
  if(!service.exists)tx.create(p.serviceRef,{name:p.name,isActive:true,createdAt:FieldValue.serverTimestamp()});
  for(let i=0;i<cs.length;i++){
   const c=cs[i];if(c.exists&&(c.data().queueId!==p.queue.id||c.data().windowNumber!==i+1))throw Error('Counter changed during migration.');
   tx.set(c.ref,{queueId:p.queue.id,windowNumber:i+1,name:c.data()?.name??`Window ${i+1}`,floor:c.data()?.floor??'',
    isActive:q.data().archived!==true,createdAt:c.data()?.createdAt??FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
  }
  tx.update(p.queue,{schemaVersion:3,serviceId:p.serviceId,windowCount:p.count});
 });changed++;
}
await db.collection('admin_audit_logs').add({adminId:null,serviceAccount:key?.client_email??'emulator',action:'migrate_erd_relations',targetType:'queue',targetId:'catalog-migration',queueCount:changed,createdAt:FieldValue.serverTimestamp()});
console.log(`Migrated ${changed} queue catalogs. Accounts, bookings, scheduling, balances and assignments were not modified.`);
