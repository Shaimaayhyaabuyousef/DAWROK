const live=new URLSearchParams(location.search).get('mode')!=='demo';
const project=fbConfig.project, dbName='projects/'+project+'/databases/(default)', root=dbName+'/documents', fs='https://firestore.googleapis.com/v1/', authApi='https://identitytoolkit.googleapis.com/v1/';
const liveCreates=['categories','facilities','notifications','subscriptions'];
let accessToken='',liveReady=false,liveBusy=false,authMessage='',expiryTimer,liveRecords={},liveLog=[],categories=[],liveEmail='';
const scopes=['https://www.googleapis.com/auth/datastore','https://www.googleapis.com/auth/identitytoolkit','https://www.googleapis.com/auth/userinfo.email'];
function landing(){document.documentElement.dir=ar?'rtl':'ltr';document.documentElement.lang=ar?'ar':'en';$('content').innerHTML='<div class="access"><section class="panel"><div class="line"><div class="kicker">DAWROK · Firebase</div><button class="lang" onclick="ar=!ar;cache.ar=ar;save();landing()">'+t('العربية','English')+'</button></div><h1>'+t('Super Admin Dashboard','لوحة تحكم الأدمن العام')+'</h1><p>'+t('Connect your project administrator account to manage live DAWROK data.','استخدمي حساب Google الذي يدير المشروع للوصول إلى بيانات دورك الفعلية.')+'</p><small dir="ltr">dawrok-f908e</small><button class="primary" '+(liveBusy?'disabled':'')+' onclick="authorizeLive()">'+(liveBusy?t('Connecting…','جارٍ الاتصال…'):t('Continue with Google','المتابعة باستخدام Google'))+'</button><p role="status">'+esc(authMessage)+'</p><a class="link" href="?mode=demo">'+t('Explore with sample data','استكشاف ببيانات تجريبية')+'</a></section></div>'}
function authorizeLive(){if(!window.google?.accounts?.oauth2){authMessage=t('Google sign-in could not load. Reload this page and try again.','تعذر تحميل تسجيل دخول Google. أعيدي تحميل الصفحة ثم حاولي مجددًا.');return landing()}const error=()=>{liveBusy=false;authMessage=t('Authorization was not completed. Check the Google account and authorized site origin.','لم يكتمل التفويض. تحققي من حساب Google وعنوان الموقع المسموح به.');landing()};google.accounts.oauth2.initTokenClient({client_id:fbConfig.clientId,scope:scopes.join(' '),include_granted_scopes:false,error_callback:error,callback:async res=>{if(!res.access_token)return error();accessToken=res.access_token;clearTimeout(expiryTimer);expiryTimer=setTimeout(()=>location.reload(),Math.max(1,Number(res.expires_in)-15)*1000);liveBusy=true;authMessage='';landing();try{const who=await googleCall('https://www.googleapis.com/oauth2/v2/userinfo');liveEmail=who.email;await syncLive();liveReady=true;render()}catch(e){accessToken='';authMessage=e.message}finally{liveBusy=false;if(!liveReady)landing()}}}).requestAccessToken({prompt:'select_account'})}
async function googleCall(url,body){let res=await fetch(url,{method:body===undefined?'GET':'POST',headers:{Authorization:'Bearer '+accessToken,...(body!==undefined?{'Content-Type':'application/json'}:{})},body:body===undefined?undefined:JSON.stringify(body),cache:'no-store',credentials:'omit'});const out=await res.json();if(!res.ok){let e=new Error(out.error?.message||String(res.status));e.status=res.status;throw e}return out}
const decode=v=>'mapValue'in v?Object.fromEntries(Object.entries(v.mapValue.fields||{}).map(([k,x])=>[k,decode(x)])):'arrayValue'in v?(v.arrayValue.values||[]).map(decode):'integerValue'in v?Number(v.integerValue):Object.values(v)[0];
const fv=v=>typeof v==='boolean'?{booleanValue:v}:typeof v==='number'?(Number.isInteger(v)?{integerValue:String(v)}:{doubleValue:v}):{stringValue:String(v)};
const fields=o=>Object.fromEntries(Object.entries(o).map(([k,v])=>[k,fv(v)]));
const doc=d=>({...Object.fromEntries(Object.entries(d.fields||{}).map(([k,v])=>[k,decode(v)])),key:d.name.split('/').pop(),path:d.name,version:d.updateTime});
async function readCollection(collectionId,keys,allDescendants=false){let out=[],cursor;do{const q={from:[{collectionId,allDescendants}],select:{fields:keys.split(' ').map(fieldPath=>({fieldPath}))},orderBy:[{field:{fieldPath:'__name__'},direction:'ASCENDING'}],limit:500};if(cursor)q.startAt={values:[{referenceValue:cursor}],before:false};const entries=await googleCall(fs+root+':runQuery',{structuredQuery:q}),batch=entries.filter(x=>x.document).map(x=>doc(x.document));out.push(...batch);cursor=batch.length===500?batch.at(-1).path:null}while(cursor);return out}
async function syncLive(){const specs={facilities:['facilities','name facilityNumber ownerUid phone address categoryId isActive isOnline'],users:['users','displayName role email phone status facilityId'],queues:['queues','service isActive archived',true],bookings:['bookings','citizenId citizenName facilityId queueId service status createdAt'],staff:['staff_profiles','fullName phone'],members:['staff_memberships','facilityId role state'],subscriptions:['subscriptions','facilityId plan amount status paidAt'],notifications:['notifications','message read createdAt',true],audit:['admin_audit_logs','action targetType targetId createdAt'],categories:['facility_categories','name nameAr nameEn isActive']};let all=Object.fromEntries(await Promise.all(Object.entries(specs).map(async([k,args])=>[k,await readCollection(...args)])));categories=all.categories.filter(x=>x.isActive);data.categories=all.categories.map((r,i)=>({id:i+1,raw:r,name:r.nameEn||r.name,arabic:r.nameAr||r.name,state:r.isActive?'Active':'Suspended'}));liveLog=all.audit.sort((a,b)=>String(b.createdAt).localeCompare(String(a.createdAt)));liveRecords={};let ids={};for(let k of Object.keys(all)){ids[k]=new Map(all[k].map((r,i)=>[r.path,i+1]));liveRecords[k]=all[k]}const ref=(k,path)=>ids[k].get(root+'/'+path);const members=new Map(all.members.map(x=>[x.key,x]));for(const k of ['facilities','users','queues','bookings','staff','subscriptions','notifications'])data[k]=all[k].map((r,i)=>{const facility=r.facilityId||r.path.split('/').at(-3),member=members.get(r.key);let obj={id:i+1,name:r.name||r.displayName||r.fullName||r.service||r.message||r.key,email:r.email||'',facility:ref('facilities','facilities/'+facility),date:r.createdAt||'',state:r.status||'',raw:r};if(k==='facilities')Object.assign(obj,{state:r.isActive?'Active':'Suspended',email:r.phone||''});if(k==='users')Object.assign(obj,{role:({citizen:'Citizen',facility:'Facility admin',employee:'Employee'})[r.role]||r.role,state:r.status==='suspended'?'Suspended':'Active'});if(k==='queues')obj.state=r.archived?'Closed':r.isActive?'Open':'Paused';if(k==='bookings')Object.assign(obj,{name:r.key,user:ref('users','users/'+r.citizenId),queue:ref('queues','facilities/'+r.facilityId+'/queues/'+r.queueId),state:({served:'Completed',waiting:'Scheduled',called:'Scheduled',cancelled:'Cancelled',absent:'Absent'})[r.status]||r.status});if(k==='staff')Object.assign(obj,{facility:ref('facilities','facilities/'+member?.facilityId),state:member?.state==='active'?'Active':'Suspended'});if(k==='notifications')obj.audience=r.path.split('/').at(-3),obj.state='Published';if(k==='subscriptions')Object.assign(obj,{amount:Number(r.amount||0),state:r.status||'Pending'});return obj})}
function liveMonths(rev){const now=new Date(),out=Array(12).fill(0);for(let r of rev?data.subscriptions:data.bookings){const d=new Date(rev?r.raw.paidAt:r.date);if(isNaN(d))continue;const n=(now.getFullYear()-d.getFullYear())*12+now.getMonth()-d.getMonth();if(n>=0&&n<12)out[11-n]+=rev?r.amount:1}return out}
function liveEvents(all){return '<div class="events">'+(liveLog.length?liveLog.slice(0,all?liveLog.length:4).map(r=>'<div class="event">'+tile('audit',0)+'<div><b>'+esc(r.action)+'</b><small>'+esc(r.targetId)+'</small></div><time>'+esc(String(r.createdAt).slice(0,10))+'</time></div>').join(''):'<p>'+t('No recorded events.','لا توجد عمليات مسجلة.')+'</p>')+'</div>'}
function liveProfile(){return head(L('settings'),esc(liveEmail))+'<div class="panel section"><b>Firebase · dawrok-f908e</b><p>'+t('Authorized through Google Cloud project permissions.','الوصول وفق صلاحيات حساب Google على المشروع.')+'</p><button class="outline" onclick="location.reload()">'+t('End session','إنهاء الجلسة')+'</button></div>'}
const writeDoc=(path,values,condition,merge=false,time)=>({update:{name:root+'/'+path,fields:fields(values)},...(merge?{updateMask:{fieldPaths:Object.keys(values)}}:{}),currentDocument:condition,...(time?{updateTransforms:[{fieldPath:time,setToServerValue:'REQUEST_TIME'}]}:{})});
const auditWrite=(action,type,id)=>writeDoc('admin_audit_logs/'+crypto.randomUUID(),{adminId:liveEmail,action,targetType:type,targetId:id},{exists:false},false,'createdAt');
const commit=async writes=>googleCall(fs+root+':commit',{writes});
const relative=r=>r.path.slice(root.length+1);
const identity=(method,body)=>googleCall(authApi+'accounts:'+method+'?key='+encodeURIComponent(fbConfig.apiKey),{...body,targetProjectId:project});
async function fetchDoc(path){try{return doc(await googleCall(fs+root+'/'+path))}catch(e){if(e.status===404)return null;throw e}}
function localPhone(v){const digits=v.replace(/[٠-٩۰-۹]/g,c=>String(c.charCodeAt(0)-(c.charCodeAt(0)>=0x6f0?0x6f0:0x660))).replace(/[\s()-]/g,'');const m=/^(?:0|\+970|00970|970)?(5[69][0-9]{7})$/.exec(digits);if(!m)throw Error(t('Enter a valid 059 or 056 mobile number.','أدخلي رقم هاتف فلسطيني يبدأ بـ 059 أو 056.'));return '0'+m[1]}
async function provision(o){const phone=localPhone(o.phone),email='p970'+phone.slice(1)+'@login.dawrok.invalid',category=await fetchDoc('facility_categories/'+o.category);if(!category?.isActive)throw Error(t('Select an active category.','اختاري فئة مفعّلة.'));const seq=await fetchDoc('admin_sequences/facility_numbers');let number=seq?Number(seq.last)+1:100000;if(!Number.isSafeInteger(number)||number<100000)throw Error('Invalid facility sequence');while(number<=999999&&(data.facilities.some(x=>String(x.raw.facilityNumber)===String(number))||await fetchDoc('facilities/'+number)))number++;if(number>999999)throw Error('Facility numbers exhausted');const id=String(number),uid=crypto.randomUUID(),label=o.name.trim(),subId=crypto.randomUUID();await identity('signUp',{localId:uid,email,password:o.password,displayName:label,returnSecureToken:false,disabled:true});let committed=false;try{await commit([writeDoc(relative(category),{isActive:true},{updateTime:category.version},true),writeDoc('admin_sequences/facility_numbers',{last:number},seq?{updateTime:seq.version}:{exists:false}),writeDoc('facilities/'+id,{facilityNumber:id,ownerUid:uid,name:label,categoryId:o.category,phone,address:o.address.trim(),isActive:true,isOnline:false,nextWindowNumber:0},{exists:false},false,'createdAt'),writeDoc('users/'+uid,{uid,email,phone,role:'facility',status:'active',facilityId:id,displayName:label},{exists:false},false,'createdAt'),writeDoc('subscriptions/'+subId,{facilityId:id,plan:o.plan,amount:Number(o.amount),currency:'USD',status:'Pending'},{exists:false},false,'createdAt'),auditWrite('Facility created','facility',id)]);committed=true}catch(e){const check=await fetchDoc('users/'+uid);if(check?.facilityId===id){committed=true}else if(!check){await identity('delete',{localId:uid});throw e}else throw e}if(committed){try{await identity('update',{localId:uid,disableUser:false})}catch{throw Error(t('Facility saved. Enable its account in Firebase Authentication to finish activation.','حُفظت المنشأة. فعّلي حسابها من Firebase Authentication لاستكمال التفعيل.'))}}}
function liveEdit(k,id){const item=id?get(k,id):null,r=item?.raw;if(id&&!r)return;const facilityOptions=data.facilities.map(x=>[x.raw.key,name(x)]);let body='',apply=null;let title=id?t('Record details','تفاصيل السجل'):addText()[k];if(r){body='<p class="muted" dir="ltr">'+esc(relative(r))+'</p>'}
if(k==='facilities'&&!id){body+=field('name',t('Facility name','اسم المنشأة'))+field('phone',t('Facility login phone','هاتف دخول المنشأة'),'','tel')+field('password',t('Initial password (12+ characters)','كلمة المرور الأولية (١٢ حرفًا على الأقل)'),'','password').replace('required','required autocomplete="new-password" minlength="12"')+select('category',t('Active category','الفئة المفعّلة'),categories.map(x=>[x.key,categoryLabel(x)]))+field('address',t('Address','العنوان')).replace('required','')+select('plan',t('Plan','الخطة'),['Basic','Professional'])+field('amount',t('Subscription amount (USD)','قيمة الاشتراك بالدولار'),0,'number');body += categoryEditor();
  apply = provision;
}
else if(k==='subscriptions'){body+=select('facilityId',L('facilities'),facilityOptions,r?.facilityId)+select('plan',t('Plan','الخطة'),['Basic','Professional'],r?.plan)+field('amount',t('Amount in USD','المبلغ بالدولار'),r?.amount??0,'number')+select('status',t('Payment status','حالة الدفعة'),['Pending','Active','Expired'],r?.status)+'<p>'+t('Mark Active after payment. Revenue is recorded in the month received.','اختاري «نشط» بعد استلام الدفعة لتسجيل الإيراد في شهر التحصيل.')+'</p>';apply=async o=>{let key=r?.key||crypto.randomUUID(),values={facilityId:o.facilityId,plan:o.plan,amount:Number(o.amount),currency:'USD',status:o.status};if(r?.paidAt&&(r.amount!==values.amount||r.facilityId!==o.facilityId))throw Error(t('Create a new subscription entry for a different payment.','أنشئي سجل اشتراك جديدًا للدفعة المختلفة.'));await commit([writeDoc('subscriptions/'+key,values,r?{updateTime:r.version}:{exists:false},!!r,o.status==='Active'&&!r?.paidAt?'paidAt':undefined),auditWrite('Subscription saved','facility',o.facilityId)])}}
else if(k==='notifications'&&r){body+='<label>'+t('Message','الرسالة')+'<textarea maxlength="2000" required name="message">'+esc(r.message)+'</textarea></label>';apply=async o=>commit([writeDoc(relative(r),{message:o.message.trim()},{updateTime:r.version},true),auditWrite('Notice updated','user',r.path.split('/').at(-3))])}
else if(k==='notifications'&&!id){body+=field('uid',t('Recipient account UID','معرّف حساب المستلم'))+'<label>'+t('Message','الرسالة')+'<textarea name="message" maxlength="2000" required></textarea></label>';apply=async o=>{if(![...liveRecords.users,...liveRecords.members].some(x=>x.key===o.uid))throw Error(t('Unknown recipient UID.','معرّف المستلم غير موجود.'));const key=crypto.randomUUID();await commit([writeDoc('users/'+o.uid+'/notifications/'+key,{type:'notice',bookingId:'',delta:0,message:o.message.trim(),senderId:liveEmail,read:false},{exists:false},false,'createdAt'),auditWrite('Notice sent','user',o.uid)])}}
else if(r&&['facilities','users','staff'].includes(k)){let fieldKey={facilities:'name',users:'displayName',staff:'fullName'}[k];body+=field(fieldKey,t('Display name','الاسم الظاهر'),r[fieldKey]||'');if(k==='facilities'){
    const options=liveRecords.categories.filter(c=>c.isActive||c.key===r.categoryId);
    body+=field('address',t('Address','العنوان'),r.address||'').replace('required','')+select('categoryId',t('Category','الفئة'),options.map(c=>[c.key,categoryLabel(c)]),r.categoryId);
  }
  apply=async o=>{
    const writes=[writeDoc(relative(r),o,{updateTime:r.version},true),auditWrite('Profile updated',{users:'user',facilities:'facility',staff:'staff'}[k],r.key)];
    if(k==='facilities'&&o.categoryId!==r.categoryId){
      const target=await fetchDoc('facility_categories/'+o.categoryId);
      if(!target?.isActive)throw Error(t('Select an active category','اختاري فئة مفعّلة'));
      writes.push(writeDoc(relative(target),{isActive:true},{updateTime:target.version},true));
    }
    await commit(writes);
  }}
else if(r){body+='<p>'+esc(display(k,item))+'</p><p>'+esc(tr(item.state))+'</p>';if(k==='bookings')body+='<p>'+esc(r.citizenName)+' · '+esc(r.service)+'</p>';if(k==='queues')body+='<p>'+esc(name(get('facilities',item.facility)))+'</p>'}
modal(title,'<form id="firebaseForm">'+body+'<p id="fbError" role="alert"></p>'+(apply?foot():'')+'</form>');if(!apply)return;$('firebaseForm').onsubmit=async e=>{e.preventDefault();const form=e.currentTarget,b=form.querySelector('.primary');b.disabled=true;let finished=false;try{await apply(Object.fromEntries(new FormData(form)));finished=true;await syncLive();$('dlg').close();render()}catch(err){$('fbError').textContent=finished?t('Saved. Reload to refresh the dashboard.','تم الحفظ. أعيدي التحميل لتحديث اللوحة.'):err.message}finally{b.disabled=finished}}}

function categoryLabel(category) {
  return t(category.nameEn, category.nameAr) || category.name || category.nameAr || category.nameEn || category.key;
}

function categoryEditor() {
  return `<details style="margin:16px 0">
    <summary class="link" style="cursor:pointer">${t('+ Add facility category', '+ إضافة فئة منشآت')}</summary>
    <label>${t('Arabic category name', 'اسم الفئة بالعربية')}<input data-name-ar dir="rtl" lang="ar" placeholder="خدمات طبية"></label>
    <label>${t('English category name', 'اسم الفئة بالإنجليزية')}<input data-name-en dir="ltr" lang="en" placeholder="Medical Services"></label>
    <label>${t('Category ID', 'معرّف الفئة')}<input data-category-id placeholder="medical" dir="ltr" maxlength="40"></label>
    <button type="button" class="outline" onclick="addFacilityCategory(this)">${t('Save category','حفظ الفئة')}</button>
    <p data-category-message role="status"></p>
  </details>`;
}

async function addFacilityCategory(button) {
  const section = button.closest('details');
  const select = button.form.elements.namedItem('category');
  const arabicInput = section.querySelector('[data-name-ar]');
  const englishInput = section.querySelector('[data-name-en]');
  const idInput = section.querySelector('[data-category-id]');
  const message = section.querySelector('[data-category-message]');
  const nameAr = arabicInput.value.trim();
  const nameEn = englishInput.value.trim();
  const id = idInput.value.trim().toLowerCase();

  if (!nameAr || !nameEn || !/^[a-z0-9_-]{2,40}$/.test(id)) {
    message.textContent = t(
      'Enter both names and a 2–40 character ID using lowercase letters, numbers, _ or -.',
      'أدخلي الاسمين بالعربية والإنجليزية ومعرّفًا من 2 إلى 40 خانة، باستخدام أحرف إنجليزية صغيرة أو أرقام أو _ أو -.'
    );
    return;
  }

  button.disabled = true;
  message.textContent = t('Saving…', 'جارٍ الحفظ…');
  try {
    const values = {name: nameAr, nameAr, nameEn, isActive: true};
    await commit([writeDoc('facility_categories/' + id, values,
      {exists:false}, false, 'createdAt')]);
    categories.push({key:id, ...values});
    select.add(new Option(categoryLabel(values), id));
    select.value = id;
    arabicInput.value = '';
    englishInput.value = '';
    idInput.value = '';
    message.textContent = t('Category saved and selected.', 'تم حفظ الفئة واختيارها للمنشأة.');
  } catch (error) {
    message.textContent = error.status === 409
      ? t('Category ID already exists.', 'معرّف الفئة مستخدم بالفعل.')
      : t('Could not save category. ', 'تعذّر حفظ الفئة. ') + error.message;
  } finally {
    button.disabled = false;
  }
}

function openCategoryForm(id) {
  const item = id ? get('categories',id) : null;
  const row = item?.raw || item || {};
  const title = id ? t('Edit category','تعديل الفئة') : t('Add category','إضافة فئة');
  const identifier = id ? '<p dir="ltr">'+esc(row.key)+'</p>' :
    field('key',t('Category ID','معرّف الفئة')).replace('required','required dir="ltr" pattern="[a-z0-9_\\-]{2,40}"');
  const inputs = identifier +
    field('nameAr',t('Arabic name','الاسم بالعربية'),row.nameAr||row.arabic||row.name) +
    field('nameEn',t('English name','الاسم بالإنجليزية'),row.nameEn||row.name) +
    select('state',t('Status','الحالة'),['Active','Suspended'],item?.state||'Active');
  adminForm(title,inputs,async form=>{
    const key = row.key || form.key.trim();
    if (!id && !/^[a-z0-9_-]{2,40}$/.test(key)) throw Error(t('Invalid category ID','معرّف الفئة غير صالح'));
    const nameAr=form.nameAr.trim(),nameEn=form.nameEn.trim();
    if(!nameAr || !nameEn)throw Error(t('Enter both names','أدخلي الاسمين'));
    if(live){
      const values={name:nameAr,nameAr,nameEn,isActive:form.state==='Active'};
      await commit([writeDoc('facility_categories/'+key,values,id?{updateTime:row.version}:{exists:false},!!id,id?undefined:'createdAt'),auditWrite(id?'Category updated':'Category created','category',key)]);
    }else{
      if(!id&&data.categories.some(x=>x.key===key))throw Error(t('ID already exists','المعرّف مستخدم بالفعل'));
      const rid=id||next('categories');
      write('categories',{id:rid,key,name:nameEn,arabic:nameAr,state:form.state},rid);
      log('categories',id?'Updated':'Created',nameAr);
    }
  });
}
function adminForm(title,body,onSave,deleteMode=false){
  modal(title,'<form id="adminAction">'+body+'<p id="actionError" role="alert"></p>'+
    (deleteMode?'<div class="formfoot"><button type="button" class="outline" onclick="dlg.close()">'+t('Cancel','إلغاء')+'</button><button class="primary">'+t('Confirm deletion','تأكيد الحذف')+'</button></div>':foot())+'</form>');
  $('adminAction').onsubmit=async event=>{
    event.preventDefault();
    const form=event.currentTarget,button=form.querySelector('.primary');
    if(button.disabled)return;
    button.disabled=true;
    let saved=false;
    try{
      await onSave(Object.fromEntries(new FormData(form)));
      saved=true;
      if(live)await syncLive();
      $('dlg').close();render();
    }catch(error){
      $('actionError').textContent=saved?t('Saved. Reload to refresh.','تم الحفظ. حدّثي الصفحة لعرض النتيجة.'):error.message;
      button.disabled=saved;
    }
  };
}
function confirmAdminDelete(k,id){
  const item=get(k,id);
  if(!item)return;
  const row=item.raw||item;
  adminForm(t('Delete record','حذف السجل'),'<p>'+esc(display(k,item))+' · '+esc(row.key||id)+'</p>',async()=>{
    if(!live){write(k,null,id);log(k,'Deleted',display(k,item));return}
    if(!['categories','subscriptions','notifications'].includes(k))throw Error(t('Unsupported action','عملية غير مدعومة'));
    if(k==='categories'){
      const query={from:[{collectionId:'facilities'}],select:{fields:[{fieldPath:'__name__'}]},
        where:{fieldFilter:{field:{fieldPath:'categoryId'},op:'EQUAL',value:{stringValue:row.key}}},limit:1};
      const result=await googleCall(fs+root+':runQuery',{structuredQuery:query});
      if(result.some(x=>x.document))throw Error(t('Reassign facilities using this category first.','انقلي المنشآت المرتبطة إلى فئة أخرى أولاً.'));
    }
    await commit([{delete:row.path,currentDocument:{updateTime:row.version}},auditWrite('Deleted',k,row.key)]);
  },true);
}
