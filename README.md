# GAME SUB — مترجم Xbox مستقل

**تطبيق iPhone وiPad جديد بواجهة SwiftUI خاصة به.** لا يعرض فيديو Xbox أو واجهة Starfold على الجوال. لا يستخدم الكاميرا ولا يطلب نسخ ولصق النصوص.

## تحميل النسخة الجديدة

**[GAME SUB iOS — Successful Build #44923315039](https://github.com/tmoath07-svg/REBOX-Translator/actions/runs/44923315039)**

من قسم **Artifacts** حمّل `GAME-SUB-iPhone-iPad-unsigned-IPA`، فك ZIP، ثم وقّع `GAME-SUB-unsigned.ipa` بشهادة iOS صالحة عبر ESign.

اسم التطبيق: **GAME SUB**. المعرّف المستقل: `com.tmoath07.gamesub`. النسخة: **1.0.0**.

## التصميم الفعلي

1. `NativeApp/Sources/GameSubApp.swift` — تطبيق مستقل جديد، مع شاشة تسجيل Microsoft عبر رمز الجهاز، البحث عن Xbox واختيار الجهاز، والاتصال التلقائي عندما يوجد جهاز واحد فقط.
2. `NativeApp/Sources/GameSubTranslator.swift` — يستقبل الإطارات من `StreamRenderer.lastFrameImage()` داخليًا بدون عرضها. Apple Vision يقرأ نص الشاشة باستخدام منطقة نسبية قابلة للتعديل، ثم Apple Translation يترجمه ويعرض **النص المترجم فقط**.
3. `NativeApp/Sources/CaptionRelay.swift` — خادم HTTP على شبكة Wi-Fi المحلية، بمنفذ حر تلقائي وتحديث نص الترجمة.
4. `NativeApp/Sources/TVReceiverPage.swift` — رابط `/tv` الذي يعرض الترجمة العربية في متصفح LG، مع تجربة اختيار HDMI 1–4 غير مضمونة.
5. `NativeApp/project.yml` و `.github/workflows/build-standalone.yml` — مشروع iOS منفصل يعمل عبر GitHub Actions لبناء IPA بدون ماك شخصي.

**المحرك المفتوح:** يستخدم مكتبات [Starfold](https://github.com/JarvanSun/Starfold) (MIT) لتسجيل الدخول واتصال Xbox والاستقبال الداخلي. لا يبني Starfold كواجهة تطبيق ولا يغير اسمه؛ مصدر GAME SUB المنفصل موجود بالكامل في `NativeApp/`.

## طريقة الاستخدام

- افتح GAME SUB وسجّل حساب Microsoft/Xbox. اختر Xbox إذا ظهر أكثر من واحد.
- يبدأ الاتصال بـ Remote Play؛ لا تظهر صورة اللعبة على الجوال؛ تظهر حالة الاتصال والنص المترجم فقط.
- اختر English → العربية، ووافق على تنزيل حزم Apple Translation عند الحاجة من إعدادات اللغات.
- حدد منطقة النص من المخطط المصغّر (مربع أزرق، من دون عرض فيديو اللعبة).
- انسخ رابط LG من التطبيق وافتحه في متصفح التلفزيون على نفس الشبكة.
- يجب إبقاء التطبيق مفتوحًا في المقدمة؛ قفل الشاشة أو تحويل التطبيق للخلفية قد يوقف البث في iOS.

## حدود يلزم اختبارها على الأجهزة الحقيقية

- **النجاح المؤكد:** إنشاء التطبيق المستقل، اختبارات المصدر، بناء Xcode، وصناعة IPA غير موقّع.
- **غير مثبت حتى الآن:** تسجيل Xbox الحقيقي، استقبال نصوص ألعاب فعلية، ترجمتها، واستمرار العرض على مدخل HDMI في LG أثناء اتصال Remote Play.
- **LG HDMI:** المتصفح العادي قد لا يستطيع دمج HTML مع صورة HDMI الحية. الرابط يعرض الترجمة عندما تفتح الصفحة؛ لا يضمن تثبيت الكلام فوق مدخل HDMI الأصلي. وقد يتطلب الأمر مستقبل webOS مناسبًا للموديل/البرمجيات.
- ترجمة Apple مجانية لكنها تعتمد على توفر زوج اللغات وموافقة الجهاز على تنزيل النماذج.
- لم تُضف أي خدمة API مدفوعة أو اشتراك أو إذن كاميرا.

## ملفات تجريبية قديمة

الملفات الأقدم تحت `ios/` و`scripts/` ليست تطبيق GAME SUB الجديد. لا تستخدم Workflow القديم `Build REBOX Translator iOS` لتنزيل النسخة الجديدة. استخدم **Build GAME SUB Standalone iOS** فقط.

## الإسناد

[Starfold (MIT)](https://github.com/JarvanSun/Starfold) — مكتبات Xbox/StreamKit; راجع [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). GAME SUB مشروع مستقل وغير تابع رسميًا لـ Microsoft أو LG أو Apple.
