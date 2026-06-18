// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'ميدي سكان';

  @override
  String get success => 'نجاح';

  @override
  String get error => 'خطأ';

  @override
  String get warning => 'تحذير';

  @override
  String get info => 'معلومة';

  @override
  String get ok => 'حسناً';

  @override
  String get cancel => 'إلغاء';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get save => 'حفظ';

  @override
  String get delete => 'حذف';

  @override
  String get logout => 'تسجيل خروج';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'الإنجليزية';

  @override
  String get arabic => 'العربية';

  @override
  String get profileSettings => 'إعدادات الحساب';

  @override
  String get adminConsole => 'لوحة الإدارة';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get signup => 'إنشاء حساب';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get home => 'الرئيسية';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get patients => 'المرضى';

  @override
  String get doctors => 'الأطباء';

  @override
  String get chats => 'المحادثات';

  @override
  String get xrays => 'الأشعة';

  @override
  String get upload => 'رفع';

  @override
  String get settings => 'الإعدادات';

  @override
  String get diagnosing => 'جاري التشخيص...';

  @override
  String get completed => 'مكتمل';

  @override
  String get pending => 'قيد الانتظار';

  @override
  String get reviewing => 'قيد المراجعة';

  @override
  String get normal => 'طبيعي';

  @override
  String get pneumonia => 'التهاب رئوي';

  @override
  String get tuberculosis => 'سل';

  @override
  String get authPleaseEnterEmailPass =>
      'الرجاء إدخال البريد الإلكتروني وكلمة المرور.';

  @override
  String get authPleaseEnterName => 'الرجاء إدخال اسمك الكامل.';

  @override
  String get authPleaseEnterPhone => 'الرجاء إدخال رقم هاتفك.';

  @override
  String get authPassLength => 'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.';

  @override
  String get authPassMismatch => 'كلمات المرور غير متطابقة.';

  @override
  String get authPleaseEnterDob => 'الرجاء إدخال تاريخ ميلادك.';

  @override
  String get authDoctorDetailsRequired =>
      'الرجاء إكمال تفاصيل التحقق الخاصة بالطبيب.';

  @override
  String get authDoctorConnected => 'تم الاتصال بالطبيب بنجاح.';

  @override
  String get authDoctorCodeInvalid =>
      'تم إنشاء الحساب، ولكن كود الطبيب غير صالح أو منتهي الصلاحية.';

  @override
  String get authFailed => 'فشلت عملية المصادقة.';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get getStarted => 'البدء';

  @override
  String get chooseAccountType => 'اختر نوع الحساب';

  @override
  String get patientDesc => 'رفع ومراجعة الأشعة';

  @override
  String get doctorDesc => 'يتطلب الموافقة على الترخيص';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get emailAddress => 'البريد الإلكتروني';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get gender => 'الجنس';

  @override
  String get male => 'ذكر';

  @override
  String get female => 'أنثى';

  @override
  String get other => 'آخر';

  @override
  String get dateOfBirth => 'تاريخ الميلاد';

  @override
  String get city => 'المدينة';

  @override
  String get country => 'البلد';

  @override
  String get doYouHaveDoctor => 'هل لديك طبيب؟';

  @override
  String get enterDoctorCodeSub => 'أدخل الكود المرسل من طبيبك.';

  @override
  String get enterDoctorCode => 'أدخل كود الطبيب';

  @override
  String get emergencyName => 'اسم جهة الاتصال للطوارئ';

  @override
  String get emergencyPhone => 'رقم هاتف الطوارئ';

  @override
  String get specialization => 'التخصص';

  @override
  String get licenseNumber => 'رقم الترخيص الطبي';

  @override
  String get licensingBody => 'جهة الترخيص';

  @override
  String get clinicName => 'اسم العيادة أو المستشفى';

  @override
  String get experienceYears => 'سنوات الخبرة';

  @override
  String get professionalAddress => 'العنوان المهني';

  @override
  String get doctorPendingWarning =>
      'تظل حسابات الأطباء معلقة حتى يقوم المسؤول بمراجعة تفاصيل الترخيص.';

  @override
  String get bio => 'النبذة المهنية';

  @override
  String get advancedAiDiagnosis => 'تشخيص ذكي ومتقدم للأشعة';

  @override
  String get systemStatusOnline => 'حالة النظام: متصل';

  @override
  String get notProvided => 'غير متوفر';

  @override
  String get otpEnterPhone => 'أدخل رقم الهاتف';

  @override
  String get otpPhoneShort => 'رقم الهاتف قصير جداً';

  @override
  String get otpMustLogin => 'يجب تسجيل الدخول لإرسال رمز التحقق.';

  @override
  String get otpSentWhatsapp => 'تم إرسال رمز التحقق عبر واتساب!';

  @override
  String get otpNetworkError => 'خطأ في الشبكة. يرجى التحقق من اتصالك.';

  @override
  String get otpEnterCode => 'أدخل الرمز المكون من 6 أرقام.';

  @override
  String get otpVerifiedSuccess => 'تم التحقق من رقم الهاتف بنجاح!';

  @override
  String get otpPhoneVerificationTitle => 'التحقق من الهاتف';

  @override
  String get otpVerified => 'تم التحقق!';

  @override
  String get otpEnterTheCode => 'أدخل الرمز';

  @override
  String get otpVerifyPhoneNumber => 'تحقق من رقم الهاتف';

  @override
  String get otpVerifiedDesc => 'تم التحقق من رقم هاتفك بنجاح.';

  @override
  String get otpSentDesc =>
      'أرسلنا رمزاً مكوناً من 6 أرقام إلى واتساب.تنتهي صلاحيته خلال 5 دقائق.';

  @override
  String get otpSendDesc =>
      'أدخل رقم الهاتف المصري للمريضلإرسال رمز التحقق عبر واتساب.';

  @override
  String get otpEgyptianFormat => 'يتم تنسيق الأرقام المصرية تلقائياً';

  @override
  String get otpSendCodeBtn => 'إرسال الرمز';

  @override
  String get otpChangeBtn => 'تغيير';

  @override
  String get otpVerificationCode => 'رمز التحقق';

  @override
  String get otpVerifyBtn => 'تحقق';

  @override
  String get otpResendIn => 'إعادة الإرسال خلال ';

  @override
  String get otpSeconds => 'ث';

  @override
  String get otpResendCodeBtn => 'إعادة إرسال الرمز';

  @override
  String get otpProceedDesc => 'تم التحقق من رقم الهاتف. يمكنك المتابعة الآن.';

  @override
  String get otpDoneBtn => 'تم';

  @override
  String get profileTitle => 'ملفي الشخصي';

  @override
  String get profileAdminDesc => 'عرض وإدارة حساب المسؤول الخاص بك';

  @override
  String get profilePatientDesc => 'عرض وإدارة معلوماتك الشخصية';

  @override
  String get profileCompletePrompt => 'الرجاء إكمال ملفك الشخصي:';

  @override
  String get profileAddName => 'أضف اسمك';

  @override
  String get profileAdmin => 'مسؤول';

  @override
  String get profilePatient => 'مريض';

  @override
  String get profilePersonalInfo => 'المعلومات الشخصية';

  @override
  String get profilePersonalInfoDesc => 'تفاصيلك الشخصية والطبية';

  @override
  String get profileEmail => 'البريد الإلكتروني';

  @override
  String get profilePhone => 'الهاتف';

  @override
  String get profileMedicalHistory => 'التاريخ الطبي';

  @override
  String get profileEdit => 'تعديل الملف الشخصي';

  @override
  String get profileMedicalSummary => 'الملخص الطبي';

  @override
  String get profileMedicalSummaryDesc => 'نظرة عامة على بياناتك الطبية';

  @override
  String get profileTotalXrays => 'إجمالي الأشعة';

  @override
  String get profileLatestUpload => 'أحدث رفع';

  @override
  String get profileNone => 'لا يوجد';

  @override
  String get profileReports => 'التقارير';

  @override
  String get profileAppearance => 'المظهر';

  @override
  String get profileThemeDesc => 'اختر المظهر المفضل لديك';

  @override
  String get profileSignOut => 'تسجيل الخروج';

  @override
  String get profileEmailRequired => 'البريد الإلكتروني مطلوب.';

  @override
  String get profilePassLength =>
      'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.';

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي';

  @override
  String get profileUpdateFailed => 'فشل تحديث الملف الشخصي';

  @override
  String get profileFullName => 'الاسم الكامل';

  @override
  String get profilePhoneNumber => 'رقم الهاتف';

  @override
  String get profileNewPassword => 'كلمة مرور جديدة';

  @override
  String get profileDob => 'تاريخ الميلاد';

  @override
  String get profileMedicalHistoryLabel => 'التاريخ الطبي';

  @override
  String get profileSaveChanges => 'حفظ التغييرات';

  @override
  String get lightMode => 'الوضع المضيء';

  @override
  String get lightModeDesc => 'استخدام المظهر الفاتح دائماً';

  @override
  String get darkModeDesc => 'استخدام المظهر الداكن دائماً';

  @override
  String get systemDefault => 'افتراضي النظام';

  @override
  String get systemDefaultDesc => 'اتباع إعدادات الجهاز';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navUpload => 'رفع';

  @override
  String get navXrays => 'الأشعة';

  @override
  String get navChat => 'المحادثة';

  @override
  String get navProfile => 'حسابي';

  @override
  String get navAI => 'ذكاء اصطناعي';

  @override
  String get navPatients => 'المرضى';

  @override
  String get navAdmin => 'الإدارة';

  @override
  String get welcomeBack => 'مرحباً بعودتك';

  @override
  String get latestHealthSummary => 'إليك أحدث ملخص صحتك.';

  @override
  String get latestAIFindings => 'أحدث نتائج الذكاء الاصطناعي';

  @override
  String get yourRecentXray => 'تحليل أشعتك الأخير';

  @override
  String get viewFullReport => 'عرض التقرير الكامل';

  @override
  String get healthRecommendations => 'التوصيات الصحية';

  @override
  String get tipsForRecovery => 'نصائح للتعافي';

  @override
  String get askAIAboutCondition => 'اسأل الذكاء عن حالتي';

  @override
  String get restRecovery => 'الراحة والتعافي';

  @override
  String get restRecoveryDesc =>
      'احصل على قدر كافي من الراحة وتجنب المجهود الشديد.';

  @override
  String get stayHydrated => 'ابق رطباً';

  @override
  String get stayHydratedDesc => 'اشرب الماء والسوائل بكثرة لتخفيف المخاط.';

  @override
  String get followUpCare => 'المتابعة الطبية';

  @override
  String get followUpCareDesc =>
      'خذ الأدوية الموصوفة وحضور جميع مواعيد المتابعة.';

  @override
  String get aiHealthAssistant => 'مساعد الصحة بالذكاء الاصطناعي';

  @override
  String get askAboutHealth => 'اسأل عن صحتك';

  @override
  String get aiMedicalAssistant => 'المساعد الطبي بالذكاء الاصطناعي';

  @override
  String get askAboutXray => 'اسأل أسئلة حول تحليلات الأشعة';

  @override
  String get quickQuestions => 'أسئلة شائعة';

  @override
  String get quickAnswers => 'إجابات سريعة';

  @override
  String get aiCapabilities => 'قدرات الذكاء الاصطناعي';

  @override
  String get healthTips => 'نصائح صحية';

  @override
  String get connectToDoctor => 'التواصل مع طبيب';

  @override
  String get enterDoctorOtpDesc =>
      'أدخل رمز التحقق المكون من 6 أرقام الذي أرسله طبيبك عبر واتساب.';

  @override
  String get enterCode => 'أدخل الرمز';

  @override
  String get noScansYet => 'لا توجد أشعة بعد';

  @override
  String get analyzed => 'تم التحليل';

  @override
  String get xraysLabel => 'الأشعة';

  @override
  String get statusLabel => 'الحالة';

  @override
  String get confidenceLabel => 'الثقة';

  @override
  String get lastUpload => 'آخر رفع';

  @override
  String get uploadXrayTitle => 'رفع أشعة سينية';

  @override
  String get uploadXrayDescPatient => 'شارك صور الأشعة السينية مع طبيبك';

  @override
  String get uploadXrayDescDoctor => 'رفع للتحليل بواسطة الذكاء الاصطناعي';

  @override
  String get uploadImageLabel => 'رفع الصورة';

  @override
  String get uploadImageHint => 'اختر صورة أشعة واضحة بحجم أقصى 10 ميجابايت';

  @override
  String get uploadImageHintDoctor => 'اسحب وأفلت أو انقر للاختيار';

  @override
  String get removeImage => 'إزالة';

  @override
  String get selectPatientLabel => 'اختر المريض';

  @override
  String get selectPatientHint => 'اختر مريضاً';

  @override
  String get uploadingText => 'جاري الرفع...';

  @override
  String get uploadSuccessMsg =>
      'تم رفع الأشعة بنجاح! سيبدأ تحليل الذكاء الاصطناعي قريباً.';

  @override
  String get uploadFailedMsg => 'فشل الرفع. تحقق من اتصالك بالإنترنت.';

  @override
  String get accountPendingTitle => 'الحساب قيد انتظار الموافقة';

  @override
  String get accountPendingDesc =>
      'حسابك في انتظار تحقق المشرف. ستتمكن من رفع صور الأشعة بمجرد الموافقة.';

  @override
  String get whatHappensNext => 'ماذا يحدث بعد ذلك؟';

  @override
  String get aiAnalysisTitle => 'تحليل الذكاء الاصطناعي';

  @override
  String get aiAnalysisDesc =>
      'سيقوم نظام الذكاء الاصطناعي الخاص بنا بتحليل الأشعة السينية لاكتشاف أي مشاكل محتملة.';

  @override
  String get doctorReviewTitle => 'مراجعة الطبيب';

  @override
  String get doctorReviewDesc =>
      'سيقوم طبيب مؤهل بمراجعة نتائج الذكاء الاصطناعي وتقديم تقييمه.';

  @override
  String get getResultsTitle => 'الحصول على النتائج';

  @override
  String get getResultsDesc =>
      'احصل على تقرير شامل يحتوي على النتائج والتوصيات.';

  @override
  String get myProfile => 'ملفي الشخصي';

  @override
  String get manageAdminProfile => 'عرض وإدارة حساب المسؤول الخاص بك';

  @override
  String get managePersonalProfile => 'عرض وإدارة معلوماتك الشخصية';

  @override
  String get manageDoctorProfile => 'عرض وإدارة معلوماتك المهنية';

  @override
  String get completeProfileMsg => 'يرجى إكمال ملفك الشخصي:';

  @override
  String get updateInfoToContinue =>
      'قم بتحديث معلوماتك للاستمرار في استخدام جميع الميزات.';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get professionalInfo => 'المعلومات المهنية';

  @override
  String get profInfoDesc => 'أوراق اعتمادك وتفاصيلك المهنية';

  @override
  String get performanceOverview => 'نظرة عامة على الأداء';

  @override
  String get perfOverviewDesc => 'إحصاءات نشاطك';

  @override
  String get appearance => 'المظهر';

  @override
  String get appearanceDesc => 'اختر المظهر المفضل لديك';

  @override
  String get account => 'الحساب';

  @override
  String get deleteAccountPatient => 'حذف حسابك وجميع بياناتك';

  @override
  String get deleteAccountDoctor => 'حذف حساب الطبيب الخاص بك بأمان';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get dob => 'تاريخ الميلاد';

  @override
  String get notSet => 'لم يتم التعيين';

  @override
  String get specialty => 'التخصص';

  @override
  String get personalInformation => 'المعلومات الشخصية';

  @override
  String get personalInfoDesc => 'تفاصيلك الشخصية وتاريخك الطبي';

  @override
  String get medicalHistory => 'التاريخ الطبي';

  @override
  String get phone => 'رقم الهاتف';

  @override
  String get totalAnalyses => 'إجمالي التحليلات';

  @override
  String get reports => 'التقارير';
}
