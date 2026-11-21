import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
const env = await initializeTestEnvironment({ projectId: 'demo-dawrok', firestore: {
  rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
}});
const stamp = () => firebase.firestore.FieldValue.serverTimestamp();
try {
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await db.doc('users/booking-citizen').set({role:'citizen', displayName:'Test Citizen'});
    await db.doc('users/booking-other').set({role:'citizen'});
    await db.doc('citizen_identity/booking-citizen').set({userId:'booking-citizen', nationalId:'123456789', status:'self_reported'});
    await db.doc('facilities/booking-facility').set({name:'Booking Facility', ownerUid:'booking-owner', isActive:true, isOnline:true});
    for (const [id, active] of [['window_1', true], ['window_2', false]]) {
      await db.doc(`facilities/booking-facility/queues/${id}`).set({windowNumber:1,service:'General',capacity:1,
        startsAtMinutes:0, endsAtMinutes:1440, isActive:active,archived:false});
    }
  });
  const db = env.authenticatedContext('booking-citizen').firestore();
  const other = env.authenticatedContext('booking-other').firestore();
  const identity = await assertSucceeds(db.doc('citizen_identity/booking-citizen').get());
  assert.equal(identity.data().nationalId, '123456789');
  await assertFails(other.doc('citizen_identity/booking-citizen').get());
  const queues = await assertSucceeds(db.collection('facilities/booking-facility/queues')
    .where('isActive','==',true).where('archived','==',false).get());
  assert.equal(queues.size,1);
  const date = new Date(Math.ceil((Date.now() + 60_000) / 1_800_000) * 1_800_000);
  const day = date.toISOString().slice(0,10).replaceAll('-','');
  const slot = date.toISOString().slice(11,16).replace(':','');
  const queue = db.doc('facilities/booking-facility/queues/window_1');
  const daily = queue.collection('days').doc(day);
  const guard = db.doc(`users/booking-citizen/booking_days/${day}`);
  const ticket = db.collection('bookings').doc();
  // Mirrors BookingService: all six reads precede the three atomic writes.
  await assertSucceeds(db.runTransaction(async tx => {
    const me = await tx.get(db.doc('users/booking-citizen'));
    const id = await tx.get(db.doc('citizen_identity/booking-citizen'));
    const facility = await tx.get(db.doc('facilities/booking-facility'));
    const q = await tx.get(queue);
    await tx.get(guard); await tx.get(daily);
    assert.equal(id.data().nationalId,'123456789');
    tx.set(guard,{uid:'booking-citizen',queues:{'booking-facility_window_1':ticket.id},slots:{[slot]:ticket.id},updatedAt:stamp()});
    tx.set(daily,{reserved:1,lastSlotStart:firebase.firestore.Timestamp.fromDate(date),lastBookingId:ticket.id,updatedAt:stamp()});
    tx.set(ticket,{citizenId:'booking-citizen',citizenName:me.data().displayName,
      facilityId:'booking-facility',facilityName:facility.data().name,
      queueId:'window_1',windowNumber:0,windowCount:1,routingVersion:2, service:q.data().service,serviceId:'',
      queuePosition:1,dayKey:day,slot,slotStart:firebase.firestore.Timestamp.fromDate(date),
      status:'waiting',checkedIn:false,postponements:0,createdAt:stamp()});
  }));
  assert.equal((await assertSucceeds(daily.get())).data().reserved,1);
  assert.equal((await assertSucceeds(db.collection('bookings').where('citizenId','==','booking-citizen').get())).size,1);
  await assertFails(other.doc(ticket.path).get());
  await assertFails(ticket.set({... (await ticket.get()).data(),citizenId:'booking-other'}));
  // Counters cannot be incremented without an associated valid booking.
  await assertFails(daily.update({reserved:2,lastBookingId:'fake',updatedAt:stamp()}));
  console.log('Citizen identity, live queues, atomic booking, ticket list and privacy regression checks passed.');
} finally { await env.cleanup(); }
