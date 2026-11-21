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
    transaction.set(facilityRef.collection('services').doc('general'),{name:'General Service',isActive:true,createdAt:firebase.firestore.FieldValue.serverTimestamp()});
    transaction.update(facilityRef, { nextWindowNumber: number });
    transaction.set(queueRef, {
      windowNumber: number,
      service: 'General Service', serviceId:'general', schemaVersion:3,
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
      linkCode: 'ABCD-EFGH-JKLM-NPQR-STUV', codeExpiresAt: expires,
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
  const staffCard = await assertSucceeds(newStaff.get());
  if (staffCard.data()?.linkCode !== 'ABCD-EFGH-JKLM-NPQR-STUV') {
    throw new Error('Generated invite code did not persist on staff card');
  }
  await assertFails(employee.doc('facilities/example-facility/staff/101').get());
  await assertSucceeds(employee.doc('staff_invites/' + hash).get());
  await assertSucceeds(join.set({
    facilityId: 'example-facility', staffId: '101',
    employeeUid: 'employee-test', employeeEmail: 'employee@example.com',
    phone: '+970 59 111 2222',
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
      linkCode: firebase.firestore.FieldValue.delete(),
      codeExpiresAt: firebase.firestore.FieldValue.delete(),
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
  const approvedStaffCard = await assertSucceeds(newStaff.get());
  if (approvedStaffCard.data()?.linkCode !== undefined) {
    throw new Error('Approved employee still contains an active link code.');
  }
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

  // Rejection never creates an active membership.
  const deniedHash = 'b'.repeat(64);
  const rejectedStaff = facility.doc('facilities/example-facility/staff/102');
  const deniedInvite = facility.doc('staff_invites/' + deniedHash);
  await assertSucceeds(facility.runTransaction(async (tx) => {
    tx.set(rejectedStaff, {
      name: 'Rejected Employee', employeeId: 'TEST-456', window: 'Window 2',
      role: 'windowOfficer', state: 'pending', description: '',
      joinStatus: 'invited', inviteHash: deniedHash,
      linkCode: 'WXYZ-2345-6789-ABCD-EFGH',
      codeExpiresAt: firebase.firestore.Timestamp.fromDate(
        new Date(Date.now() + 24 * 60 * 60 * 1000)),
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(deniedInvite, {
      facilityId: 'example-facility', staffId: '102', status: 'issued',
      issuedAt: firebase.firestore.FieldValue.serverTimestamp(),
      expiresAt: firebase.firestore.Timestamp.fromDate(
        new Date(Date.now() + 24 * 60 * 60 * 1000)),
    });
  }));
  const rejectedEmployee = testEnv.authenticatedContext('rejected-user',
    {email: 'rejected@example.com'}).firestore();
  await assertSucceeds(rejectedEmployee.doc('staff_join_requests/' + deniedHash).set({
    facilityId: 'example-facility', staffId: '102',
    employeeUid: 'rejected-user', employeeEmail: 'rejected@example.com',
    phone: '+970 59 333 4444',
    status: 'requested', createdAt: firebase.firestore.FieldValue.serverTimestamp(),
  }));
  await assertSucceeds(facility.runTransaction(async (tx) => {
    await tx.get(rejectedStaff);
    await tx.get(facility.doc('staff_join_requests/' + deniedHash));
    await tx.get(deniedInvite);
    tx.update(rejectedStaff, {
      joinStatus: 'rejected', state: 'suspended',
      linkCode: firebase.firestore.FieldValue.delete(),
      codeExpiresAt: firebase.firestore.FieldValue.delete(),
    });
    tx.update(facility.doc('staff_join_requests/' + deniedHash), {
      status: 'rejected', reviewedAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(deniedInvite, {
      status: 'revoked', updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
  }));
  const rejectedDoc = await assertSucceeds(rejectedEmployee
    .doc('staff_join_requests/' + deniedHash).get());
  if (rejectedDoc.data()?.status !== 'rejected') {
    throw new Error('Rejected employee was not notified in Firestore');
  }
  const rejectedMembership = await assertSucceeds(rejectedEmployee
    .doc('staff_memberships/rejected-user').get());
  if (rejectedMembership.exists) throw new Error('Rejected employee has membership!');
  console.log('Employee rejection and denied membership tests passed.');

  console.log('Staff invitation, approval and required profile tests passed.');

  console.log('Facility owner queue transaction and listing permissions passed.');

  console.log('Rules compiled; owner, stranger and anonymous access smoke tests passed.');
} finally {
  await testEnv.cleanup();
}
