import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
const env=await initializeTestEnvironment({projectId:'demo-dawrok',firestore:{rules:readFileSync(new URL('../firestore.rules',import.meta.url),'utf8')}});
const stamp=()=>firebase.firestore.FieldValue.serverTimestamp();
const seed=(p,d)=>env.withSecurityRulesDisabled(c=>c.firestore().doc(p).set(d));
const owner=env.authenticatedContext('erd-owner').firestore(),citizen=env.authenticatedContext('erd-citizen',{email:'citizen@example.test'}).firestore();
const admin=env.authenticatedContext('erd-admin',{admin:true}).firestore();
const qdata={windowNumber:1,windowCount:1,service:'Bread',serviceId:'bread',schemaVersion:3,counter:'A',capacity:50,rewardCapacity:0,waitingCount:0,waitingMinutes:15,shift:'morning',startsAtMinutes:0,endsAtMinutes:1440,isActive:false,archived:false};
const counter={queueId:'window_1',windowNumber:1,name:'Window 1',floor:'',isActive:true};
try{
 await seed('users/erd-owner',{role:'facility',status:'active',facilityId:'erd'});
 await seed('facilities/erd',{name:'ERD',ownerUid:'erd-owner',isActive:true,isOnline:true});
 // Registration fields and email-based identity remain unchanged.
 const profile={uid:'erd-citizen',role:'citizen',displayName:'Citizen',email:'citizen@example.test',phone:'0591234567',address:'',photoUrl:'',providers:['password'],createdAt:stamp()};
 await assertSucceeds(citizen.doc('users/erd-citizen').set(profile));
 await assertFails(citizen.doc('users/erd-citizen').update({password_hash:'not-allowed'}));
 await assertFails(citizen.doc('users/erd-citizen').update({role:'admin'}));
 const q=owner.doc('facilities/erd/queues/window_1'),service=owner.doc('facilities/erd/services/bread'),c=owner.doc('facilities/erd/counters/window_1_1');
 await assertFails(q.set({...qdata,createdAt:stamp()})); // Missing service.
 const batch=owner.batch();batch.set(service,{name:'Bread',isActive:true,createdAt:stamp()});batch.set(q,{...qdata,createdAt:stamp()});batch.set(c,{...counter,createdAt:stamp(),updatedAt:stamp()});await assertSucceeds(batch.commit());
 await assertFails(q.update({service:'Different service'}));
 await assertFails(q.update({serviceId:'missing'}));
 await assertFails(c.update({queueId:'another',updatedAt:stamp()}));
 await assertFails(owner.doc('facilities/erd/counters/missing_1').set({...counter,queueId:'missing',isActive:false,createdAt:stamp(),updatedAt:stamp()}));
 await assertFails(citizen.doc(service.path).update({isActive:false}));
 // Full booking id and authenticated actor must match the facility.
 await seed('bookings/erd-ticket',{citizenId:'erd-citizen',facilityId:'erd',queueId:'window_1',windowNumber:0,status:'waiting'});
 await seed('bookings/erd-foreign',{citizenId:'somebody',facilityId:'elsewhere',queueId:'window_1',status:'waiting'});
 const log={actorUid:'erd-owner',actorRole:'facility',staffId:'',bookingId:'erd-ticket',label:'Ticket check-in',identifier:'erd-ticket',outcome:'verified',createdAt:stamp()};
 await assertSucceeds(owner.doc('facilities/erd/queue_logs/good').set(log));
 await assertFails(owner.doc('facilities/erd/queue_logs/wrong-actor').set({...log,actorUid:'somebody'}));
 await assertFails(owner.doc('facilities/erd/queue_logs/wrong-booking').set({...log,bookingId:'erd-foreign'}));
 await assertFails(owner.doc('facilities/erd/queue_logs/good').update({outcome:'invalid'}));
 await assertFails(citizen.doc('facilities/erd/queue_logs/good').get());
 const point=citizen.doc('citizen_accounts/erd-citizen/point_transactions/result_erd-ticket');
 await assertFails(point.set({bookingId:'erd-ticket',points:5,reason:'served',createdAt:stamp()}));
 await seed(point.path,{bookingId:'erd-ticket',points:5,reason:'served',createdAt:firebase.firestore.Timestamp.now()});
 await assertSucceeds(point.get());await assertFails(point.update({points:500}));await assertFails(point.delete());
 const notice={type:'notice',bookingId:'erd-ticket',delta:0,message:'Your queue has an update.',senderId:'erd-admin',read:false,createdAt:stamp()};
 const event=admin.doc('citizen_accounts/erd-citizen/events/admin-notice');
 await assertSucceeds(event.set(notice));
 await assertFails(admin.doc('citizen_accounts/erd-citizen/events/wrong-ticket').set({...notice,bookingId:'erd-foreign'}));
 await assertFails(citizen.doc('citizen_accounts/erd-citizen/events/fake-notice').set(notice));
 await assertSucceeds(citizen.doc(event.path).update({read:true}));
 await assertFails(citizen.doc(event.path).update({message:'changed'}));
 const audit=admin.doc('admin_audit_logs/erd-test'),record={adminId:'erd-admin',action:'review',targetType:'queue',targetId:'erd/window_1',createdAt:stamp()};
 await assertSucceeds(audit.set(record));await assertFails(audit.update({action:'replace'}));await assertFails(citizen.doc(audit.path).get());
 console.log('PASS ERD: unchanged account fields, canonical service/counter relations, authentic scan actor, immutable point ledger, linked notifications and admin-only immutable audit.');
}finally{await env.cleanup();}
