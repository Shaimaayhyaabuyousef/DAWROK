import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
const env=await initializeTestEnvironment({projectId:'demo-dawrok',firestore:{rules:readFileSync(new URL('../firestore.rules',import.meta.url),'utf8')}});
const client=uid=>env.authenticatedContext(uid).firestore();
const stamp=()=>firebase.firestore.FieldValue.serverTimestamp();
const seed=(path,data)=>env.withSecurityRulesDisabled(c=>c.firestore().doc(path).set(data));
const lane=(db,q,w)=>db.doc(`facilities/windows/queues/${q}/lanes/${w}`);
async function ticket(id,q='multi',future=false){await seed(`bookings/${id}`,{citizenId:'queueCitizen',facilityId:'windows',queueId:q,windowNumber:0,routingVersion:2,status:'waiting',checkedIn:false,postponements:0,slotStart:firebase.firestore.Timestamp.fromMillis(Date.now()+(future?3600000:-60000))});}
async function call(actor,id,q,w){const db=client(actor);return db.runTransaction(async tx=>{
 const r=db.doc(`bookings/${id}`),l=lane(db,q,w);await tx.get(r);await tx.get(l);
 tx.update(r,{status:'called',windowNumber:w,calledAt:stamp()});tx.set(l,{ticketId:id,updatedAt:stamp()});
});}
async function postpone(actor,id,q,w){const db=client(actor);const batch=db.batch();batch.update(db.doc(`bookings/${id}`),{status:'waiting',windowNumber:0,postponements:1,postponedAt:stamp()});batch.set(lane(db,q,w),{ticketId:'',updatedAt:stamp()});return batch.commit();}
async function complete(actor,id,q,w,outcome='served') {
 const db=client(actor),r=db.doc(`bookings/${id}`),a=db.doc('citizen_accounts/queueCitizen'),l=lane(db,q,w);
 return db.runTransaction(async tx=>{await tx.get(r);await tx.get(l);const old=(await tx.get(a)).data()??{points:0,streak:0,suspendedAt:null,reviewRequired:false};
 tx.update(r,{status:outcome,closedAt:stamp()});tx.set(l,{ticketId:'',updatedAt:stamp()});
 tx.set(a,{points:old.points+(outcome==='served'?5:-5),streak:outcome==='served'?0:old.streak+1,suspendedAt:old.suspendedAt,reviewRequired:false,lastBookingId:id,lastAction:outcome,updatedAt:stamp()});
 tx.set(a.collection('events').doc(`result_${id}`),{type:outcome,bookingId:id,delta:outcome==='served'?5:-5,read:false,createdAt:stamp()});});
}
try{
 await seed('users/windowOwner',{role:'facility',status:'active',facilityId:'windows'});
 await seed('facilities/windows',{ownerUid:'windowOwner',isActive:true,isOnline:true,name:'Windows'});
 for(const [q,count] of [['multi',2],['direct',0]])await seed(`facilities/windows/queues/${q}`,{windowNumber:1,windowCount:count,isActive:true,archived:false});
 for(const uid of ['one','two','unassigned']){await seed(`staff_memberships/${uid}`,{facilityId:'windows',role:'windowOfficer',state:'active'});await seed(`staff_profiles/${uid}`,{profileCompleted:true});}
 const config=client('windowOwner').doc('facilities/windows/operations/assignments');
 await assertSucceeds(config.set({assignments:{one:{queueId:'multi',windowNumber:1},two:{queueId:'multi',windowNumber:2}},updatedAt:stamp()}));
 await assertFails(client('one').doc(config.path).update({assignments:{one:{queueId:'multi',windowNumber:2}},updatedAt:stamp()}));
 const configurable=client('windowOwner').doc('facilities/windows/queues/window_7');
 await assertSucceeds(configurable.set({windowNumber:7,windowCount:0,service:'General',counter:'A',capacity:50,waitingCount:0,waitingMinutes:15,shift:'morning',startsAtMinutes:480,endsAtMinutes:1020,isActive:false,archived:false,createdAt:stamp()}));
 await assertSucceeds(configurable.update({windowCount:3}));
 await assertFails(configurable.update({windowCount:21}));
 await assertFails(configurable.update({windowCount:-1}));
 await ticket('race');
 const race=await Promise.allSettled([call('one','race','multi',1),call('two','race','multi',2)]);
 assert.equal(race.filter(r=>r.status==='fulfilled').length,1,'one ticket can be claimed only once');
 const b=(await client('windowOwner').doc('bookings/race').get()).data();
 const winner=b.windowNumber===1?'one':'two',other=b.windowNumber===1?'two':'one';
 await assertFails(client(other).doc('bookings/race').update({checkedIn:true}));
 await assertSucceeds(client(winner).doc('bookings/race').update({checkedIn:true}));
 await ticket('busy');await assertFails(call(winner,'busy','multi',b.windowNumber));
 await assertFails(client(winner).doc('bookings/race').update({status:'waiting',windowNumber:0,postponements:1,postponedAt:stamp()}));
 await assertSucceeds(postpone(winner,'race','multi',b.windowNumber));
 assert.equal((await lane(client('windowOwner'),'multi',b.windowNumber).get()).data().ticketId,'');
 await assertSucceeds(call('windowOwner','busy','multi',b.windowNumber)); // Owner retains access with employees.
 await assertSucceeds(client(winner).doc('bookings/busy').update({checkedIn:true}));
 await assertSucceeds(complete(winner,'busy','multi',b.windowNumber));
 await assertFails(complete(winner,'busy','multi',b.windowNumber));
 await ticket('different');await assertFails(call('one','different','multi',2));
 await assertFails(call('unassigned','different','multi',1));
 await ticket('directTicket','direct');await assertSucceeds(call('windowOwner','directTicket','direct',0));
 await assertSucceeds(complete('windowOwner','directTicket','direct',0,'absent'));
 await ticket('directWrong','direct');await assertFails(call('windowOwner','directWrong','direct',1));
 await ticket('future','multi',true);await assertFails(call(other,'future','multi',b.windowNumber===1?2:1));
 await seed(`staff_memberships/${other}`,{facilityId:'windows',role:'windowOfficer',state:'suspended'});
 await assertFails(call(other,'different','multi',b.windowNumber===1?2:1));
 console.log('PASS windows: owner with/without staff, direct service, assignment scope, no double claim, busy lane, atomic postponement, future tickets and suspended employee denied.');
}finally{await env.cleanup();}
