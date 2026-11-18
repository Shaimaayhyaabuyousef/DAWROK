import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
const env=await initializeTestEnvironment({projectId:'demo-dawrok',firestore:{rules:readFileSync(new URL('../firestore.rules',import.meta.url),'utf8')}});
const stamp=()=>firebase.firestore.FieldValue.serverTimestamp();
const defaults={points:0,streak:0,suspendedAt:null,reviewRequired:false,lastBookingId:'seed',lastAction:'seed'};
const time=new Date(Math.ceil((Date.now()+60000)/1800000)*1800000),day=time.toISOString().slice(0,10).replaceAll('-',''),slot=time.toISOString().slice(11,16).replace(':','');
const client=uid=>env.authenticatedContext(uid).firestore();
async function seed(path,data){await env.withSecurityRulesDisabled(c=>c.firestore().doc(path).set(data));}
async function user(uid,points=0){await seed(`users/${uid}`,{role:'citizen',displayName:uid});await seed(`citizen_accounts/${uid}`,{...defaults,points});}
async function queue(q,capacity=2,rewardCapacity=1){await seed(`facilities/reliability/queues/${q}`,{windowNumber:1,service:'General',capacity,rewardCapacity,startsAtMinutes:0,endsAtMinutes:1440,isActive:true,archived:false});}
async function reserve(uid,q,reward='none',{skipDebit=false,debit=100,position}={}){
 const db=client(uid),ticket=db.collection('bookings').doc(),guard=db.doc(`users/${uid}/booking_days/${day}`),cap=db.doc(`facilities/reliability/queues/${q}/days/${day}`),acc=db.doc(`citizen_accounts/${uid}`);
 let observed;
 for(let attempt=0;;attempt++){try{
 await db.runTransaction(async tx=>{const a=(await tx.get(acc)).data()??defaults,g=(await tx.get(guard)).data()??{},c=(await tx.get(cap)).data()??{reserved:0};observed=c.reserved;
 tx.set(guard,{uid,queues:{...g.queues,[`reliability_${q}`]:ticket.id},slots:{...g.slots,[slot]:ticket.id},updatedAt:stamp()});
 tx.set(cap,{reserved:c.reserved+1,lastSlotStart:firebase.firestore.Timestamp.fromDate(time),rewardReserved:(c.rewardReserved??0)+(reward==='extra'?1:0),lastBookingId:ticket.id,updatedAt:stamp()});
 tx.set(ticket,{citizenId:uid,citizenName:uid,facilityId:'reliability',facilityName:'Test',queueId:q,windowNumber:1,service:'General',queuePosition:position??c.reserved+1,dayKey:day,slot,slotStart:firebase.firestore.Timestamp.fromDate(time),status:'waiting',checkedIn:false,postponements:0,createdAt:stamp(),reward});
 if(reward!=='none'&&!skipDebit)tx.set(acc,{...a,points:a.points-debit,lastBookingId:ticket.id,lastAction:'redeem',updatedAt:stamp()});
 tx.set(acc.collection('events').doc(`book_${ticket.id}`),{type:'booking',bookingId:ticket.id,delta:reward==='none'?0:-100,read:false,createdAt:stamp()});});return ticket.id;
 }catch(e){if(e.code!=='permission-denied'||attempt>=2||(await cap.get({source:'server'})).data()?.reserved===observed)throw e;}}
}
async function called(uid,id){await seed(`bookings/${id}`,{citizenId:uid,facilityId:'reliability',status:'called',checkedIn:true,postponements:0});}
async function close(id,outcome='served',actor='owner'){
 const db=client(actor),ticket=db.doc(`bookings/${id}`);
 return db.runTransaction(async tx=>{const b=(await tx.get(ticket)).data(),acc=db.doc(`citizen_accounts/${b.citizenId}`),a=(await tx.get(acc)).data()??defaults;
 const absent=outcome==='absent',ban=absent&&!a.suspendedAt&&a.streak+1>=3,review=a.reviewRequired||(absent&&a.suspendedAt&&Date.now()>=a.suspendedAt.toMillis()+604800000);
 tx.update(ticket,{status:outcome,closedAt:stamp()});tx.set(acc,{points:a.points+(absent?-5:5),streak:!absent||ban?0:a.streak+1,suspendedAt:ban?stamp():a.suspendedAt,reviewRequired:!!review,lastBookingId:id,lastAction:outcome,updatedAt:stamp()});
 tx.set(acc.collection('events').doc(`result_${id}`),{type:outcome,bookingId:id,delta:absent?-5:5,read:false,createdAt:stamp()});});
}
try{
 await seed('users/owner',{role:'facility',status:'active',facilityId:'reliability'});await seed('facilities/reliability',{ownerUid:'owner',name:'Test',isActive:true,isOnline:true});
 await user('new');await queue('normal');
 await user('turnA');await user('turnB');await user('turnFake');await queue('turns',5);
 await assertFails(reserve('turnFake','turns','none',{position:99}));
 const turnIds=await Promise.all([reserve('turnA','turns'),reserve('turnB','turns')]);
 const turns=await Promise.all(turnIds.map(id=>client('owner').doc(`bookings/${id}`).get()));
 assert.deepEqual(turns.map(d=>d.data().queuePosition).sort(),[1,2]);
 await assertFails(client('owner').doc(`bookings/${turnIds[0]}`).update({queuePosition:9}));

 const welcome=client('new').doc('citizen_accounts/new/events/welcome');const w={type:'welcome',bookingId:'',delta:0,read:false,createdAt:stamp()};await assertSucceeds(welcome.set(w));await assertFails(welcome.set(w));await assertSucceeds(welcome.update({read:true}));
 const id=await reserve('new','normal');await client('owner').doc(`bookings/${id}`).update({status:'called',calledAt:stamp()});await client('owner').doc(`bookings/${id}`).update({checkedIn:true});await assertSucceeds(close(id));assert.equal((await client('new').doc('citizen_accounts/new').get()).data().points,5);await assertFails(close(id));await assertFails(client('new').doc('citizen_accounts/new').update({points:999}));
 await user('blocked',150);for(let i=0;i<3;i++){await called('blocked',`miss${i}`);await assertSucceeds(close(`miss${i}`,'absent'));}let a=(await client('blocked').doc('citizen_accounts/blocked').get()).data();assert.equal(a.points,135);assert.ok(a.suspendedAt);await queue('blocked');await assertFails(reserve('blocked','blocked'));await assertFails(reserve('blocked','blocked','priority'));
 await seed('citizen_accounts/blocked',{...a,suspendedAt:firebase.firestore.Timestamp.fromMillis(Date.now()-8*86400000)});await called('blocked','repeat');await close('repeat','absent');assert.equal((await client('blocked').doc('citizen_accounts/blocked').get()).data().reviewRequired,true);await assertFails(reserve('blocked','blocked'));
 await assertSucceeds(client('blocked').collection('reports').add({uid:'blocked',reporterRole:'citizen',reporterFacilityId:'',type:'app',facilityId:'',facilityName:'',anonymous:true,hasPhoto:false,message:'Please review my booking restriction.',status:'open',createdAt:stamp()}));await assertFails(client('new').doc('citizen_accounts/blocked/events/result_repeat').get());await assertFails(client('blocked').doc('citizen_accounts/blocked').update({reviewRequired:false}));await assertSucceeds(env.authenticatedContext('admin',{admin:true}).firestore().doc('citizen_accounts/blocked').update({streak:0,suspendedAt:null,reviewRequired:false,updatedAt:stamp()}));
 await user('poor',99);await user('rich',100);await queue('priority');await assertFails(reserve('poor','priority','priority'));await assertFails(reserve('rich','priority','priority',{skipDebit:true}));await assertFails(reserve('rich','priority','priority',{debit:1}));await assertSucceeds(reserve('rich','priority','priority'));assert.equal((await client('rich').doc('citizen_accounts/rich').get()).data().points,0);
 await user('extraA',100);await user('extraB',100);await queue('extra',1,1);await seed(`facilities/reliability/queues/extra/days/${day}`,{reserved:1,rewardReserved:0,lastBookingId:'seed'});
 const results=await Promise.allSettled([reserve('extraA','extra','extra'),reserve('extraB','extra','extra')]);assert.equal(results.filter(r=>r.status==='fulfilled').length,1);const balances=await Promise.all(['extraA','extraB'].map(async uid=>(await client(uid).doc(`citizen_accounts/${uid}`).get()).data().points));assert.equal(balances.reduce((a,b)=>a+b),100);
 await user('zeroReward',100);await queue('zero',1,0);await seed(`facilities/reliability/queues/zero/days/${day}`,{reserved:1,lastBookingId:'seed'});await assertFails(reserve('zeroReward','zero','extra'));
 await seed('staff_memberships/operator',{facilityId:'reliability',state:'active',role:'windowOfficer'});await seed('staff_profiles/operator',{profileCompleted:true});await called('new','employeeTicket');await assertSucceeds(close('employeeTicket','served','operator'));
 await seed('users/fresh',{role:'citizen'});await called('fresh','firstResult');await assertSucceeds(close('firstResult'));assert.equal((await client('fresh').doc('citizen_accounts/fresh').get()).data().points,5);
 console.log('PASS: welcome, scoring once, fraud denial, suspension, review/report, reward debit, concurrent last place, employee scoring.');
}finally{await env.cleanup();}
