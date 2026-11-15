import { readFileSync } from 'node:fs';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

// Intentionally loads and compiles this rules file, unlike emulator start alone.
// The project is a demo emulator project; no production data is accessible.
const testEnv = await initializeTestEnvironment({
  projectId: 'demo-dawrok',
  firestore: {
    rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
  },
});
try {
  const owner = testEnv.authenticatedContext('test-owner').firestore();
  const stranger = testEnv.authenticatedContext('test-stranger').firestore();
  const anonymous = testEnv.unauthenticatedContext().firestore();
  await assertSucceeds(owner.doc('users/test-owner').get());
  await assertFails(stranger.doc('users/test-owner').get());
  await assertFails(anonymous.doc('users/test-owner').get());

  // Regression for the facility's Add Queue button. Both writes happen in
  // the same transaction, exactly as in FacilityQueueStore.create().
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const admin = ctx.firestore();
    await admin.doc('users/facility-owner').set({
      uid: 'facility-owner', role: 'facility', status: 'active',
      facilityId: 'example-facility',
    });
    await admin.doc('facilities/example-facility').set({
      ownerUid: 'facility-owner', name: 'Example Facility',
      isActive: true, isOnline: false, nextWindowNumber: 0,
    });
  });
  const facility = testEnv.authenticatedContext('facility-owner').firestore();
  const facilityRef = facility.doc('facilities/example-facility');
  const queueRef = facility.doc('facilities/example-facility/queues/window_1');
  await assertSucceeds(facility.runTransaction(async (transaction) => {
    const existing = await transaction.get(facilityRef);
    const number = (existing.data()?.nextWindowNumber ?? 0) + 1;
    transaction.update(facilityRef, { nextWindowNumber: number });
    transaction.set(queueRef, {
      windowNumber: number,
      service: 'General Service',
      counter: 'A',
      capacity: 50,
      waitingCount: 0,
      waitingMinutes: 10,
      shift: 'morning',
      startsAtMinutes: 480,
      endsAtMinutes: 810,
      isActive: false,
      archived: false,
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
  }));
  const saved = await assertSucceeds(queueRef.get());
  if (!saved.exists) throw new Error('Facility queue transaction did not persist');
  const listed = await assertSucceeds(facility
      .collection('facilities/example-facility/queues').get());
  if (listed.size !== 1) {
    throw new Error('Owner cannot see the queue created in Firestore');
  }
  await assertFails(stranger
      .collection('facilities/example-facility/queues').get());
  console.log('Facility owner queue transaction and listing permissions passed.');

  console.log('Rules compiled; owner, stranger and anonymous access smoke tests passed.');
} finally {
  await testEnv.cleanup();
}
