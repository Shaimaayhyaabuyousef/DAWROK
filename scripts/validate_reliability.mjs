import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
const env=await initializeTestEnvironment({projectId:'demo-dawrok',firestore:{rules:readFileSync(new URL('../firestore.rules',import.meta.url),'utf8')}});
const stamp=()=>firebase.firestore.FieldValue.serverTimestamp();
const defaults={points:0,streak:0,suspendedAt:null,reviewRequired:false,lastBookingId:'seed',lastAction:'seed'};
const time=new Date(Math.ceil((Date.now()+60000)/1800000)*1800000),day=new Intl.DateTimeFormat('sv-SE',{timeZone:'Asia/Gaza'}).format(time).replaceAll('-',''),slot=time.toISOString().slice(11,16).replace(':','');
const client=uid=>env.authenticatedContext(uid).firestore();
async function seed(path,data){await env.withSecurityRulesDisabled(c=>c.firestore().doc(path).set(data));}
async function user(uid,points=0){await seed(`users/${uid}`,{role:'citizen',displayName:uid});await seed(`citizen_accounts/${uid}`,{...defaults,points});}
async function queue(q,capacity=2,rewardCapacity=1){await seed(`facilities/reliability/queues/${q}`,{windowNumber:1,service:'General',capacity,rewardCapacity,startsAtMinutes:0,endsAtMinutes:1440,isActive:true,archived:false});}
async function reserve(uid,q,reward='none',{skipDebit=false,debit=100,position,target,eligible=false}={}){
 const db=client(uid),ticket=db.collection('bookings').doc(),guard=db.doc(`users/${uid}/booking_days/${day}`),cap=db.doc(`facilities/reliability/queues/${q}/days/${day}`),acc=db.doc(`citizen_accounts/${uid}`);
 let observed;
 for(let attempt=0;;attempt++){try{
 await db.runTransaction(async tx=>{const a=(await tx.get(acc)).data()??defaults,g=(await tx.get(guard)).data()??{},c=(await tx.get(cap)).data()??{reserved:0};observed=c.reserved;
 tx.set(guard,{uid,queues:{...g.queues,[`reliability|General`]:ticket.id},slots:{...g.slots,[slot]:ticket.id},updatedAt:stamp()});
 tx.set(cap,{reserved:c.reserved+1,lastSlotStart:firebase.firestore.Timestamp.fromDate(time),rewardReserved:(c.rewardReserved??0)+(reward==='extra'?1:0),lastBookingId:ticket.id,updatedAt:stamp()},{merge:true});
 const offers=db.collection('facilities/reliability/queues/'+q+'/priority_offers');
 if(target){tx.delete(offers.doc(target));tx.update(db.doc('bookings/'+target),{dispatchPosition:c.reserved+1,priorityBuyer:ticket.id});}
 if(eligible)tx.set(offers.doc(ticket.id),{slotStart:firebase.firestore.Timestamp.fromDate(time),position:c.reserved+1});
 tx.set(ticket,{...(eligible?{offersPriority:true}:{}),...(target?{priorityTarget:target,dispatchPosition:1}:{}),citizenId:uid,citizenName:uid,facilityId:'reliability',facilityName:'Test',queueId:q,windowNumber:0,windowCount:1,routingVersion:2,service:'General',serviceId:'',queuePosition:position??c.reserved+1,dayKey:day,slot,slotStart:firebase.firestore.Timestamp.fromDate(time),status:'waiting',checkedIn:false,postponements:0,createdAt:stamp(),reward});
 if(reward!=='none'&&!skipDebit)tx.set(acc.collection('point_transactions').doc(`book_${ticket.id}`),{bookingId:ticket.id,points:-100,reason:'redeem',createdAt:stamp()});
 if(reward!=='none'&&!skipDebit)tx.set(acc,{...a,points:a.points-debit,lastBookingId:ticket.id,lastAction:'redeem',updatedAt:stamp()});
 tx.set(acc.collection('events').doc(`book_${ticket.id}`),{type:'booking',bookingId:ticket.id,delta:reward==='none'?0:-100,read:false,createdAt:stamp()});});return ticket.id;
 }catch(e){if(e.code!=='permission-denied'||attempt>=2||(await cap.get({source:'server'})).data()?.reserved===observed)throw e;}}
}
async function called(uid,id){await seed(`bookings/${id}`,{citizenId:uid,facilityId:'reliability',queueId:'normal',windowNumber:1,status:'called',calledAt:firebase.firestore.Timestamp.fromMillis(Date.now()-610000),checkedIn:!id.startsWith('miss') && id!=='repeat',postponements:0});}
async function close(id,outcome='served',actor='owner'){
 const db=client(actor),ticket=db.doc(`bookings/${id}`);
 return db.runTransaction(async tx=>{const b=(await tx.get(ticket)).data(),acc=db.doc(`citizen_accounts/${b.citizenId}`),a=(await tx.get(acc)).data()??defaults;
 const lane=b.routingVersion===2?db.doc(`facilities/reliability/queues/${b.queueId}/lanes/${b.windowNumber}`):null; if(lane)await tx.get(lane);
 const absent=outcome==='absent',ban=absent&&!a.suspendedAt&&a.streak+1>=3,review=a.reviewRequired||(absent&&a.suspendedAt&&Date.now()>=a.suspendedAt.toMillis()+604800000);
 if(lane)tx.set(lane,{ticketId:'',updatedAt:stamp()});
 tx.update(ticket,{status:outcome,closedAt:stamp()});tx.set(acc,{points:a.points+(absent?-5:5),streak:!absent||ban?0:a.streak+1,suspendedAt:ban?stamp():a.suspendedAt,reviewRequired:!!review,lastBookingId:id,lastAction:outcome,updatedAt:stamp()});
 tx.set(acc.collection('point_transactions').doc(`result_${id}`),{bookingId:id,points:absent?-5:5,reason:outcome,createdAt:stamp()});
 tx.set(acc.collection('events').doc(`result_${id}`),{type:outcome,bookingId:id,delta:absent?-5:5,read:false,createdAt:stamp()});});
}
async function cancelBooking(actor,uid,q,id,{facility=false,paid=false,extra=false,calledWindow}={}) {
 const db=client(actor), batch=db.batch(), acc=db.doc('citizen_accounts/'+uid);
 const cap=db.doc('facilities/reliability/queues/'+q+'/days/'+day);
 batch.update(db.doc('bookings/'+id),{status:'cancelled',cancelledBy:facility?'facility':'citizen',closedAt:stamp()});
 if(calledWindow!==undefined)batch.set(db.doc('facilities/reliability/queues/'+q+'/lanes/'+calledWindow),{ticketId:'',updatedAt:stamp()});
 batch.update(cap,{cancelled:firebase.firestore.FieldValue.increment(1),lastCancelled:id,updatedAt:stamp(),
   ...(extra?{rewardReserved:firebase.firestore.FieldValue.increment(-1)}:{})});
 const guard=db.doc('users/'+uid+'/booking_days/'+day);
 batch.update(guard,{[new firebase.firestore.FieldPath('queues','reliability|General')]:firebase.firestore.FieldValue.delete(),['slots.'+slot]:firebase.firestore.FieldValue.delete(),lastCancelled:id,updatedAt:stamp()});
 if(paid){
   batch.update(acc,{points:firebase.firestore.FieldValue.increment(100),lastAction:'refund',lastBookingId:id,updatedAt:stamp()});
   batch.set(acc.collection('point_transactions').doc('refund_'+id),{bookingId:id,points:100,reason:'refund',createdAt:stamp()});
 }
 batch.set(acc.collection('events').doc('cancel_'+id),{bookingId:id,type:facility?'service_cancelled':'cancelled',delta:paid?100:0,read:false,createdAt:stamp()});
 await batch.commit();
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
 const id=await reserve('new','normal');await env.withSecurityRulesDisabled(c=>c.firestore().doc(`bookings/${id}`).update({slotStart:firebase.firestore.Timestamp.fromMillis(Date.now()-60000)}));const ownerDb=client('owner');const call=ownerDb.batch();call.update(ownerDb.doc(`bookings/${id}`),{status:'called',windowNumber:1,calledAt:stamp()});call.set(ownerDb.doc('facilities/reliability/queues/normal/lanes/1'),{ticketId:id,updatedAt:stamp()});await call.commit();await client('owner').doc(`bookings/${id}`).update({checkedIn:true});await assertSucceeds(close(id));assert.equal((await client('new').doc('citizen_accounts/new').get()).data().points,5);await assertFails(close(id));await assertFails(client('new').doc('citizen_accounts/new').update({points:999}));
 await user('blocked',150);for(let i=0;i<3;i++){await called('blocked',`miss${i}`);await assertSucceeds(close(`miss${i}`,'absent'));}let a=(await client('blocked').doc('citizen_accounts/blocked').get()).data();assert.equal(a.points,135);assert.ok(a.suspendedAt);await queue('blocked');await assertFails(reserve('blocked','blocked'));await assertFails(reserve('blocked','blocked','priority'));
 await seed('citizen_accounts/blocked',{...a,suspendedAt:firebase.firestore.Timestamp.fromMillis(Date.now()-8*86400000)});await called('blocked','repeat');await close('repeat','absent');assert.equal((await client('blocked').doc('citizen_accounts/blocked').get()).data().reviewRequired,true);await assertFails(reserve('blocked','blocked'));
 await assertSucceeds(client('blocked').collection('reports').add({uid:'blocked',reporterRole:'citizen',reporterFacilityId:'',type:'app',facilityId:'',facilityName:'',anonymous:true,hasPhoto:false,message:'Please review my booking restriction.',status:'open',createdAt:stamp()}));await assertFails(client('new').doc('citizen_accounts/blocked/events/result_repeat').get());await assertFails(client('blocked').doc('citizen_accounts/blocked').update({reviewRequired:false}));await assertSucceeds(env.authenticatedContext('admin',{admin:true}).firestore().doc('citizen_accounts/blocked').update({streak:0,suspendedAt:null,reviewRequired:false,updatedAt:stamp()}));
 await user('poor',99);await user('rich',100);await queue('priority');await assertFails(reserve('poor','priority','priority'));await assertFails(reserve('rich','priority','priority',{skipDebit:true}));await assertFails(reserve('rich','priority','priority',{debit:1}));await assertFails(reserve('rich','priority','priority'));assert.equal((await client('rich').doc('citizen_accounts/rich').get()).data().points,100);
 await user('extraA',100);await user('extraB',100);await queue('extra',1,1);await seed(`facilities/reliability/queues/extra/days/${day}`,{reserved:1,rewardReserved:0,lastBookingId:'seed'});
 const results=await Promise.allSettled([reserve('extraA','extra','extra'),reserve('extraB','extra','extra')]);assert.equal(results.filter(r=>r.status==='fulfilled').length,1);const balances=await Promise.all(['extraA','extraB'].map(async uid=>(await client(uid).doc(`citizen_accounts/${uid}`).get()).data().points));assert.equal(balances.reduce((a,b)=>a+b),100);
 await queue('swap',4);await user('eligible');await seed('citizen_accounts/eligible',{...defaults,streak:1});
 const waiting=await reserve('eligible','swap','none',{eligible:true});
 const replayRef=client('eligible').collection('bookings').where('citizenId','==','eligible').where(firebase.firestore.FieldPath.documentId(),'==',waiting);
 assert.equal((await replayRef.get({source:'server'})).docs[0].id,waiting);
 const swapped=await assertSucceeds(reserve('rich','swap','priority',{target:waiting}));
 assert.equal((await client('rich').doc('citizen_accounts/rich').get()).data().points,0);
 await user('otherBuyer',100);await assertFails(reserve('otherBuyer','swap','priority',{target:waiting}));
 await assertFails(cancelBooking('owner','rich','swap',swapped,{facility:true,paid:true}));
 await assertSucceeds(cancelBooking('rich','rich','swap',swapped,{paid:true}));
 await assertFails(cancelBooking('rich','rich','swap',swapped,{paid:true}));
 assert.equal((await client('rich').doc('citizen_accounts/rich').get()).data().points,100);
 const next=await reserve('rich','swap');
 assert.equal((await client('rich').doc('bookings/'+next).get()).data().queuePosition,3);
 const closeDay=client('owner').doc('facilities/reliability/queues/swap/closures/'+day);
 await assertSucceeds(closeDay.set({closedAt:stamp(),pending:true}));
 await assertFails(reserve('otherBuyer','swap'));
 await assertSucceeds(cancelBooking('owner','rich','swap',next,{facility:true}));
 const paidUid=results[0].status==='fulfilled'?'extraA':'extraB';
 const paidBooking=results.find(r=>r.status==='fulfilled').value;
 const owner=client('owner');
 await env.withSecurityRulesDisabled(c=>c.firestore().doc('bookings/'+paidBooking).update({slotStart:firebase.firestore.Timestamp.fromMillis(Date.now()-60000)}));
 const take=owner.batch();
 take.update(owner.doc('bookings/'+paidBooking),{status:'called',windowNumber:1,calledAt:stamp()});
 take.set(owner.doc('facilities/reliability/queues/extra/lanes/1'),{ticketId:paidBooking,updatedAt:stamp()});
 await assertSucceeds(take.commit());
 await assertFails(cancelBooking(paidUid,paidUid,'extra',paidBooking,{paid:true,extra:true}));
 await assertSucceeds(client('owner').doc('facilities/reliability/queues/extra/closures/'+day).set({closedAt:stamp(),pending:true}));
 await assertFails(close(paidBooking,'absent'));
 await assertSucceeds(cancelBooking(paidUid,paidUid,'extra',paidBooking,{facility:true,paid:true,extra:true,calledWindow:1}));
 assert.equal((await client(paidUid).doc('citizen_accounts/'+paidUid).get()).data().points,100);
 await user('zeroReward',100);await queue('zero',1,0);await seed(`facilities/reliability/queues/zero/days/${day}`,{reserved:1,lastBookingId:'seed'});await assertFails(reserve('zeroReward','zero','extra'));
 await seed('staff_memberships/operator',{facilityId:'reliability',state:'active',role:'windowOfficer'});await seed('staff_profiles/operator',{profileCompleted:true});await seed('facilities/reliability/operations/assignments',{assignments:{operator:{queueId:'normal',windowNumber:1}}});await called('new','employeeTicket');await assertSucceeds(close('employeeTicket','served','operator'));
 await seed('users/fresh',{role:'citizen'});await called('fresh','firstResult');await assertSucceeds(close('firstResult'));assert.equal((await client('fresh').doc('citizen_accounts/fresh').get()).data().points,5);
 console.log('PASS booking lifecycle: server recovery lookup, grace period, eligible priority swap, cancellation, monotonic numbering, closure and one-time refund.');
 console.log('PASS: welcome, scoring once, fraud denial, suspension, review/report, reward debit, concurrent last place, employee scoring.');
}finally{await env.cleanup();}
