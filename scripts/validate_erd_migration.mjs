import assert from 'node:assert/strict';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Emulator only');
const projectId='demo-dawrok';
await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`,{method:'DELETE'});
initializeApp({projectId});
const db=getFirestore(),run=promisify(execFile);
const fixtures={
 'users/migration-citizen':{email:'citizen@example.test',phone:'0591234567',role:'citizen'},
 'citizen_accounts/migration-citizen':{points:135,streak:2,reviewRequired:false},
 'bookings/migration-ticket':{citizenId:'migration-citizen',queuePosition:7,slotStart:123,status:'waiting'},
 'facilities/migration':{ownerUid:'owner',name:'Facility'},
 'facilities/migration/operations/assignments':{assignments:{employee:{queueId:'window_1',windowNumber:1}}},
 'facilities/migration/queues/window_1':{service:'Bread',windowCount:2,capacity:50,archived:false},
 'facilities/migration/queues/window_2':{service:'Direct',windowCount:0,capacity:20,archived:false},
};
for(const [path,data]of Object.entries(fixtures))await db.doc(path).set(data);
const migrate=apply=>run(process.execPath,[new URL('./migrate_erd_relations.mjs',import.meta.url).pathname,...(apply?['--apply']:[])]);
await migrate(false);
for(const [path,data]of Object.entries(fixtures))assert.deepEqual((await db.doc(path).get()).data(),data,'dry run does not write');
assert.equal((await db.collection('facilities/migration/services').get()).size,0);
await migrate(true);
await migrate(true); // Rerunning is safe and preserves account/booking state.
for(const [path,data]of Object.entries(fixtures)){
 const actual=(await db.doc(path).get()).data();
 if(path.includes('/queues/')){
  const {serviceId,schemaVersion,...rest}=actual;
  assert.equal(schemaVersion,3);assert.equal(typeof serviceId,'string');assert.deepEqual(rest,data);
 }else assert.deepEqual(actual,data);
}
assert.equal((await db.collection('facilities/migration/counters').get()).size,2);
assert.equal((await db.collection('facilities/migration/services').get()).size,2);
assert.equal((await db.collection('admin_audit_logs').get()).size,2);
console.log('PASS migration: dry run, idempotent apply, zero-window queues, unchanged accounts, bookings, balances and assignments.');

const numberScript = new URL('./migrate_facility_numbers.mjs', import.meta.url).pathname;
const legacy = db.doc('facilities/migration');
await run(process.execPath, [numberScript]);
assert.equal((await legacy.get()).get('facilityNumber'), undefined);
await Promise.all([run(process.execPath, [numberScript, '--apply']),
  run(process.execPath, [numberScript, '--apply'])]);
assert.equal((await legacy.get()).get('facilityNumber'), '100000');
await db.doc('facilities/another').set({name: 'Another facility'});
await run(process.execPath, [numberScript, '--apply']);
assert.equal((await db.doc('facilities/another').get()).get('facilityNumber'), '100001');
assert.equal((await legacy.get()).get('facilityNumber'), '100000');
assert.deepEqual((await db.doc('bookings/migration-ticket').get()).data(), fixtures['bookings/migration-ticket']);
console.log('PASS facility numbers: preview, concurrent backfill, stable distinct numbers, intact bookings.');
