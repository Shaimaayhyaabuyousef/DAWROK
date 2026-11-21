import {initializeApp} from 'firebase-admin/app';
import {getFirestore, FieldPath} from 'firebase-admin/firestore';
import {allocateFacilityNumber} from './facility_numbers.mjs';

const projectId = process.env.FIRESTORE_EMULATOR_HOST ? 'demo-dawrok' : 'dawrok-f908e';
initializeApp({projectId});
const db = getFirestore();
const apply = process.argv.includes('--apply');
const facilities = await db.collection('facilities').orderBy(FieldPath.documentId())
  .select('facilityNumber').get();
const pending = [];
const seen = new Set();
for (const facility of facilities.docs) {
  const number = facility.get('facilityNumber');
  if (number === undefined) {
    pending.push(facility.ref);
  } else if (typeof number !== 'string' || !/^[1-9][0-9]{5}$/.test(number) || seen.has(number)) {
    throw new Error('Invalid or duplicate saved facility number at ' + facility.ref.path);
  } else {
    seen.add(number);
  }
}
console.log(projectId, apply ? 'Apply' : 'Dry run', '— facilities needing a number:', pending.length);
if (apply) {
  for (const ref of pending) {
    await db.runTransaction(async tx => {
      const current = await tx.get(ref);
      if (!current.exists || current.get('facilityNumber') !== undefined) return;
      const facilityNumber = await allocateFacilityNumber(db, tx);
      tx.update(ref, {facilityNumber});
    });
  }
}
