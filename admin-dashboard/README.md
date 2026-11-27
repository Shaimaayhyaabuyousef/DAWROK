# لوحة إدارة DAWROK

لوحة إدارة DAWROK بالعربية والإنجليزية مع فئات المنشآت وإجراءات الإدارة وربط Firebase.

## التشغيل على Windows
افتحي مجلد admin-dashboard في VS Code، ثم شغّلي في الطرفية (يتطلب Python 3):

```powershell
py -m http.server 5000 --bind 127.0.0.1 --directory dist
```

افتحي http://localhost:5000/?mode=demo لتجربة الواجهة ببيانات محلية، أو http://localhost:5000/ لفتح تسجيل الدخول إلى المشروع الحقيقي. لإيقاف الخادم اضغطي Ctrl+C.

## الملفات
- dist/index.html — نقطة الدخول.
- dist/style.css — التصميم والاستجابة لأحجام الشاشات.
- dist/app.js — التنقل، الجداول، المخططات، نصوص الواجهة بالعربية والإنجليزية، والوضع التجريبي.
- dist/firebase-live.js — تسجيل الدخول عبر Google، قراءة Firestore وتنفيذ عمليات الإدارة المدعومة.
- dist/firebase-config.js — إعدادات عميل الويب لمشروع dawrok-f908e.

## النشر على نطاقك
ارفعي محتويات dist إلى جذر أي استضافة ملفات ثابتة تدعم HTTPS بحيث يصبح index.html في جذر الموقع. أضيفي أصل الموقع الجديد (البروتوكول واسم النطاق) إلى Authorized JavaScript origins في عميل الويب المشار إليه في firebase-config.js ضمن Google Auth Platform. يتطلب الوضع الفعلي حساب Google مخوّلًا على مشروع Firebase. البيانات الفعلية تبقى في مشروع Firebase. عند تعديل الملفات، أعيدي رفع محتويات dist لنشر الإصدار الجديد.

## إدارة النسخ
يمكنك وضع المجلد في مستودع خاص مستقل أو داخل مشروع DAWROK في مجلد admin-dashboard. ملفات اللوحة مكتوبة بـ HTML وCSS وJavaScript وتعمل مستقلة عن عملية بناء Flutter.
