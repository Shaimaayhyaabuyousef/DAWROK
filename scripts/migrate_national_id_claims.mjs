// Creates national_id_claims/{nationalId} for existing citizen accounts.
// Run with GOOGLE_APPLICATION_CREDENTIALS set to a private service account.
//   node migrate_national_id_claims.mjs            (preview)
//   node migrate_national_id_claims.mjs --apply    (write)
// Duplicates are listed and NOT claimed: review them manually.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault() });
const db = getFirestore();
const apply = process.argv.includes('--apply');
const owners = new Map();
for (const doc of (await db.collection('citizen_identity').get()).docs) {
  const id = doc.data().nationalId;
  if (typeof id !== 'string' || !/^\d{9}$/.test(id)) continue;
  owners.set(id, [...(owners.get(id) ?? []), doc.id]);
}
let created = 0;
for (const [id, uids] of owners) {
  if (uids.length > 1) {
    console.log(`DUPLICATE ${id.slice(0, 2)}*****${id.slice(-2)}: ${uids.join(', ')}`);
    continue;
  }
  const ref = db.doc(`national_id_claims/${id}`);
  if ((await ref.get()).exists) continue;
  if (apply) await ref.create({ uid: uids[0], createdAt: FieldValue.serverTimestamp() });
  created++;
}
console.log(`${apply ? 'Created' : 'Would create'} ${created} claims.`);
