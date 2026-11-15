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

  // Employee invite -> claim -> owner approval -> mandatory profile.
  const hash = 'a'.repeat(64);
  const newStaff = facility.doc('facilities/example-facility/staff/101');
  const invite = facility.doc('staff_invites/' + hash);
  const ts = firebase.firestore.FieldValue.serverTimestamp();
  const expires = firebase.firestore.Timestamp.fromDate(
    new Date(Date.now() + 24 * 60 * 60 * 1000));
  await assertSucceeds(facility.runTransaction(async (tx) => {
    tx.set(newStaff, {
      name: 'Example Employee', employeeId: 'TEST-123',
      window: 'Window 1', role: 'windowOfficer', state: 'pending',
      description: '', joinStatus: 'invited', inviteHash: hash,
      createdAt: ts,
    });
    tx.set(invite, {
      facilityId: 'example-facility', staffId: '101',
      status: 'issued', issuedAt: ts, expiresAt: expires,
    });
  }));
  const employee = testEnv.authenticatedContext('employee-test',
    {email: 'employee@example.com'}).firestore();
  const join = employee.doc('staff_join_requests/' + hash);
  await assertSucceeds(employee.doc('staff_invites/' + hash).get());
  await assertSucceeds(join.set({
    facilityId: 'example-facility', staffId: '101',
    employeeUid: 'employee-test', employeeEmail: 'employee@example.com',
    status: 'requested', createdAt: firebase.firestore.FieldValue.serverTimestamp(),
  }));
  const membership = facility.doc('staff_memberships/employee-test');
  const employeeMember = employee.doc('staff_memberships/employee-test');
  await assertFails(employee.doc('facilities/example-facility/queues/window_1').get());
  await assertFails(employee.doc('staff_profiles/employee-test').set({
    uid: 'employee-test', fullName: 'Example Employee', phone: '0591234567',
    address: 'Test address', emergencyPhone: '0597654321',
    profileCompleted: true, createdAt: ts, updatedAt: ts,
  }));
  await assertSucceeds(facility.runTransaction(async (tx) => {
    const staff = await tx.get(newStaff);
    const claim = await tx.get(facility.doc('staff_join_requests/' + hash));
    const token = await tx.get(invite);
    if (!staff.exists || !claim.exists || !token.exists) {
      throw new Error('Missing staff join prerequisites');
    }
    tx.update(newStaff, {
      state: 'active', joinStatus: 'approved', linkedUid: 'employee-test',
    });
    tx.update(facility.doc('staff_join_requests/' + hash), {
      status: 'approved', reviewedAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(invite, {
      status: 'redeemed', updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(membership, {
      facilityId: 'example-facility', staffId: '101',
      role: 'windowOfficer', window: 'Window 1',
      inviteHash: hash, state: 'active',
      approvedAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
  }));
  await assertSucceeds(employeeMember.get());
  const profile = employee.doc('staff_profiles/employee-test');
  await assertFails(employee.doc('facilities/example-facility/queues/window_1').get());
  await assertSucceeds(profile.set({
    uid: 'employee-test', fullName: 'Example Employee',
    phone: '0591234567', address: 'Test Address',
    emergencyPhone: '0597654321', profileCompleted: true,
    createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
  }));
  await assertSucceeds(employee.doc('facilities/example-facility/queues/window_1').get());
  await assertFails(stranger.doc('staff_memberships/employee-test').get());
  console.log('Staff invitation, approval and required profile tests passed.');

  console.log('Facility owner queue transaction and listing permissions passed.');

  console.log('Rules compiled; owner, stranger and anonymous access smoke tests passed.');
} finally {
  await testEnv.cleanup();
}
