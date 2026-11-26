import {loginId, localMobile} from './phone_login.mjs';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { allocateFacilityNumber } from './facility_numbers.mjs';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

// Run locally as a trusted admin. NEVER put service-account credentials,
// passwords or staff private data into this repository.
// DAWROK_FACILITY_PASSWORD comes from an environment variable, not CLI args.
// Example:
// node scripts/provision_facility.mjs 059XXXXXXX "Example Clinic" medical
const [phone, name, categoryId] = process.argv.slice(2);
const password = process.env.DAWROK_FACILITY_PASSWORD;
if (!phone || !name || !categoryId || !password || password.length < 12) {
  throw new Error('Usage: DAWROK_FACILITY_PASSWORD=<strong secret> node scripts/provision_facility.mjs <phone> <name> <categoryId>');
}
initializeApp({ credential: applicationDefault() });
const db = getFirestore();
const category = await db.collection('facility_categories').doc(categoryId).get();
if (!category.exists || category.data()?.isActive !== true) {
  throw new Error('Create and activate this facility category first.');
}
const user = await getAuth().createUser({
  email: loginId(phone), password, displayName: name.trim(),
});
try {
  const facilityNumber = await db.runTransaction(async tx => {
    const number = await allocateFacilityNumber(db, tx);
    const facility = db.collection('facilities').doc(number);
    tx.create(facility, {
      facilityNumber: number, ownerUid: user.uid, name: name.trim(), categoryId,
      phone: localMobile(phone), address: '', isActive: true, isOnline: false,
      nextWindowNumber: 0, createdAt: FieldValue.serverTimestamp(),
    });
    tx.create(db.collection('users').doc(user.uid), {
      uid: user.uid, email: loginId(phone), phone: localMobile(phone), role: 'facility',
      status: 'active', facilityId: facility.id, displayName: name.trim(),
      createdAt: FieldValue.serverTimestamp(),
    });
    return number;
  });
  console.log('Created facility number:', facilityNumber);
} catch (e) {
  await getAuth().deleteUser(user.uid);
  throw e;
}
