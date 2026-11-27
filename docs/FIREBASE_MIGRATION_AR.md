# DAWROK — Firebase migration (pilot)

هذه التعديلات موجودة في فرع feature/firebase-facilities-queues-bookings، ولا تُنشر قواعد Firebase تلقائيًا عند دمج الكود.

## البداية من قاعدة فارغة
- Admin ينشئ التصنيفات وحسابات المنشآت فقط عبر Firebase Admin SDK؛ Signup للمواطنين فقط.
- facility_categories/{id}: name, isActive, createdAt.
- facilities/{id}: ownerUid, name, categoryId, phone, address, isActive, isOnline, nextWindowNumber.
- users/{facilityUid}: role='facility', status='active', facilityId, email.
- كل منشأة تبدأ بصفر طوابير وصفر موظفين.

## أدوات الإدارة على جهاز موثوق
1. شغّل npm install --prefix scripts.
2. ضع Service Account JSON خارج GitHub، واحفظ مساره في GOOGLE_APPLICATION_CREDENTIALS.
3. PowerShell:
   $env:GOOGLE_APPLICATION_CREDENTIALS='C:\secure\dawrok-admin-key.json'
   node scripts/create_category.mjs medical "Medical Services"
   $env:DAWROK_FACILITY_PASSWORD='your-strong-temporary-password'
   node scripts/provision_facility.mjs owner@example.com "Example Clinic" medical
4. احذف كلمة المرور من متغيرات البيئة بعد التنفيذ. لا تشارك Service Account مطلقًا.

## نشر قواعد Firestore
- راجع firestore.rules واختبرها، ثم: firebase deploy --only firestore:rules --project dawrok-f908e
- لا يمكن لعميل Flutter استخدام Admin SDK.

## المجموعات
- facilities/{fid}/queues/window_{n}: يبدأ الطابور غير مفعّل؛ الحذف أرشفة لتبقى سجلات الحجوزات.
- facilities/{fid}/staff/{id}: سجلات موظفين يملكها مدير المنشأة.
- facilities/{fid}/queue_logs/{id}: سجلات QR والاستدعاء والتأجيل والخدمة.
- bookings/{id}: التذكرة ذات المصدر الواحد في Firestore.
- users/{uid}/booking_days/{UTCyyyymmdd}: منع طابور مكرر أو نفس الفترة في اليوم.
- facilities/{fid}/queues/{qid}/days/{UTCyyyymmdd}: حجز السعة اليومية للطابور.
- users، citizen_identity، demo_identity_checks تحافظ على بنية تسجيل المواطن السابقة.

## سيناريوهات الحجز
- كل تذكرة تشغل فترة محددة طولها 30 دقيقة ضمن ساعات عمل الطابور.
- معاملة Firestore تفحص السعة والتفعيل وتضيف التذكرة والحاجز والحجز اليومي معًا.
- لا يمكن للمواطن تكرار طابور خلال يوم UTC واحد حتى لو أتم خدمته.
- يستطيع حجز طابور آخر في فترة مختلفة، وليس في الفترة نفسها.
- صاحب المنشأة يستطيع استدعاء تذكرة، التحقق من QR الموجود في Firestore، إنهاء الخدمة، التأجيل وتسجيل الغياب.

## حدود مهمة قبل الإنتاج
- تطبيق قواعد اليوم حسب UTC وليس التوقيت المحلي؛ يجب نقله إلى منطق خادم موثوق يعتمد توقيت المنشأة قبل إطلاق حقيقي.
- DEMO لا يمثل تحققًا حقيقيًا من الهوية.
- إدارة سجلات الموظفين تعمل، لكن رموز دعوة الموظفين وتسجيل دخولهم بشكل مستقل غير مفعّلين بعد؛ يجب توفير خادم موثوق قبل السماح بها.
- تحقق من قواعد Firestore بالـ Emulator، ومن التزامن، وخطوط الأيقونات، وواجهات Web/Android.
- لا تُرفع صور الهويات إلى Storage على خطة Spark الحالية.

## اختبارات إلزامية
1. لا توجد منشآت: فهرس المواطن فارغ ولا توجد حجوزات تجريبية.
2. Admin ينشئ تصنيفًا ثم منشأة؛ تدخل المنشأة وتبدأ بدون طوابير أو موظفين.
3. المالك ينشئ طابورًا ويفعله ثم يجعل المنشأة Online.
4. المواطن يحجز عند 10:00، ويُرفض نفس الطابور في اليوم ونفس الفترة بأي طابور آخر.
5. يسمح له بالحجز بطابور آخر الساعة 10:30 عند وجود سعة.
6. مسح QR وتغيير الحالات والسجلات تحفظ في Firestore.
7. مستخدم آخر لا يستطيع إدارة منشأة أو قراءة سجلات موظفيها.
8. طلبان متزامنان من نفس المواطن لا يمكنهما تجاوز حاجز الحجز اليومي.
