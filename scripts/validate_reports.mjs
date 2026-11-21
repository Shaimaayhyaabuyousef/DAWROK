import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
const env=await initializeTestEnvironment({projectId:'demo-dawrok',firestore:{rules:readFileSync(new URL('../firestore.rules',import.meta.url),'utf8')}});
const stamp=()=>firebase.firestore.FieldValue.serverTimestamp();
const db=uid=>env.authenticatedContext(uid).firestore();
const base=(uid,role='citizen')=>({uid,reporterRole:role,reporterFacilityId:role==='citizen'?'':'reports-facility',type:'app',facilityId:'',facilityName:'',message:'The app is not showing my booking.',anonymous:true,hasPhoto:false,status:'open',createdAt:stamp()});
try{
 await env.withSecurityRulesDisabled(async c=>{const d=c.firestore();await Promise.all([
 d.doc('users/report-citizen').set({role:'citizen'}),d.doc('users/report-other').set({role:'citizen'}),
 d.doc('users/report-owner').set({role:'facility',status:'active',facilityId:'reports-facility'}),
 d.doc('facilities/reports-facility').set({name:'Family Bakery',ownerUid:'report-owner',isActive:true,isOnline:false}),
 d.doc('staff_memberships/report-staff').set({facilityId:'reports-facility',state:'active',role:'windowOfficer'}),
 d.doc('staff_memberships/report-suspended').set({facilityId:'reports-facility',state:'suspended',role:'windowOfficer'}),
 ]);});
 const citizen=db('report-citizen'),owner=db('report-owner'),staff=db('report-staff');
 await assertSucceeds(citizen.doc('reports/report-new').get());
 await assertSucceeds(citizen.doc('reports/report-app').set(base('report-citizen')));
 const facility={...base('report-citizen'),type:'facility',facilityId:'reports-facility',facilityName:'Family Bakery'};
 await assertSucceeds(citizen.doc('reports/report-facility').set(facility));
 await assertSucceeds(owner.doc('reports/report-owner-app').set(base('report-owner','facility')));
 await assertSucceeds(staff.doc('reports/report-staff-app').set(base('report-staff','employee')));
 await assertFails(owner.doc('reports/forbidden-owner').set({...base('report-owner','facility'),type:'facility',facilityId:'reports-facility',facilityName:'Family Bakery'}));
 await assertFails(staff.doc('reports/forbidden-staff').set({...facility,uid:'report-staff'}));
 await assertFails(citizen.doc('reports/spoof-role').set(base('report-citizen','facility')));
 await assertFails(citizen.doc('reports/spoof-uid').set(base('report-other')));
 await assertFails(citizen.doc('reports/spoof-name').set({...facility,facilityName:'Fake'}));
 await assertFails(citizen.doc('reports/unknown-facility').set({...facility,facilityId:'missing'}));
 await assertFails(db('report-suspended').doc('reports/suspended').set(base('report-suspended','employee')));
 await assertFails(db('unregistered').doc('reports/unregistered').set(base('unregistered')));
 await assertFails(env.unauthenticatedContext().firestore().doc('reports/unauthenticated').set(base('report-citizen')));
 await assertFails(citizen.doc('reports/long').set({...base('report-citizen'),message:'x'.repeat(501)}));
 await assertFails(citizen.doc('reports/short').set({...base('report-citizen'),message:'short'}));
 await assertFails(citizen.doc('reports/fake-status').set({...base('report-citizen'),status:'resolved'}));
 await assertFails(citizen.doc('reports/missing-photo').set({...base('report-citizen'),hasPhoto:true}));
 await assertFails(citizen.doc('reports/fake-anonymous').set({...base('report-citizen'),anonymous:'true'}));
 await assertFails(owner.doc('reports/report-facility').get());await assertFails(db('report-other').doc('reports/report-app').get());
 await assertSucceeds(citizen.collection('reports').where('uid','==','report-citizen').get());
 await assertFails(citizen.collection('reports').get());
 await assertFails(citizen.doc('reports/report-app').update({message:'Replaced after submission'}));
 await assertFails(citizen.doc('reports/report-app').delete());
 const photo=bytes=>({bytes:firebase.firestore.Blob.fromUint8Array(new Uint8Array(bytes)),contentType:'image/jpeg',createdAt:stamp()});
 async function withPhoto(id,size=100,extra={}){const batch=citizen.batch();batch.set(citizen.doc(`reports/${id}`),{...base('report-citizen'),hasPhoto:true});batch.set(citizen.doc(`reports/${id}/attachments/photo`),{...photo(size),...extra});return batch.commit();}
 await assertSucceeds(withPhoto('photo-valid'));await assertFails(withPhoto('photo-large',200001));await assertFails(withPhoto('photo-empty',0));await assertFails(withPhoto('photo-type',100,{contentType:'application/javascript'}));
 assert.equal((await citizen.doc('reports/photo-large').get()).exists,false);
 await assertSucceeds(citizen.doc('reports/photo-valid/attachments/photo').get());await assertFails(owner.doc('reports/photo-valid/attachments/photo').get());
 await assertFails(citizen.doc('reports/report-app/attachments/photo').set(photo(10)));
 await assertFails(citizen.doc('reports/photo-valid/attachments/photo').update(photo(10)));
 const admin=env.authenticatedContext('report-admin',{admin:true}).firestore();await assertSucceeds(admin.doc('reports/report-facility').get());await assertSucceeds(admin.doc('reports/photo-valid/attachments/photo').get());await assertSucceeds(admin.doc('reports/report-app').update({status:'resolved',response:'Thank you. We fixed it.'}));
 await env.withSecurityRulesDisabled(c=>c.firestore().doc('users/report-staff/notifications/reply').set({read:false,message:'Reviewed'}));
 await assertSucceeds(staff.doc('users/report-staff/notifications/reply').get());
 await assertSucceeds(staff.doc('users/report-staff/notifications/reply').update({read:true}));
 await assertFails(owner.doc('users/report-staff/notifications/reply').get());
 await assertFails(staff.doc('users/report-staff/notifications/reply').update({message:'Changed'}));
 console.log('PASS reports: all three roles, citizen-only facility reports, privacy, validation, atomic photos, immutable submission and admin response.');
}finally{await env.cleanup();}
