import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MediScan AI'**
  String get appTitle;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Profile Settings'**
  String get profileSettings;

  /// No description provided for @adminConsole.
  ///
  /// In en, this message translates to:
  /// **'Admin Console'**
  String get adminConsole;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @patients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get patients;

  /// No description provided for @doctors.
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get doctors;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @xrays.
  ///
  /// In en, this message translates to:
  /// **'X-Rays'**
  String get xrays;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @diagnosing.
  ///
  /// In en, this message translates to:
  /// **'Diagnosing...'**
  String get diagnosing;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @reviewing.
  ///
  /// In en, this message translates to:
  /// **'Reviewing'**
  String get reviewing;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @pneumonia.
  ///
  /// In en, this message translates to:
  /// **'Pneumonia'**
  String get pneumonia;

  /// No description provided for @tuberculosis.
  ///
  /// In en, this message translates to:
  /// **'Tuberculosis'**
  String get tuberculosis;

  /// No description provided for @authPleaseEnterEmailPass.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email and password.'**
  String get authPleaseEnterEmailPass;

  /// No description provided for @authPleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name.'**
  String get authPleaseEnterName;

  /// No description provided for @authPleaseEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number.'**
  String get authPleaseEnterPhone;

  /// No description provided for @authPassLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get authPassLength;

  /// No description provided for @authPassMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authPassMismatch;

  /// No description provided for @authPleaseEnterDob.
  ///
  /// In en, this message translates to:
  /// **'Please enter your date of birth.'**
  String get authPleaseEnterDob;

  /// No description provided for @authDoctorDetailsRequired.
  ///
  /// In en, this message translates to:
  /// **'Please complete your doctor verification details.'**
  String get authDoctorDetailsRequired;

  /// No description provided for @authDoctorConnected.
  ///
  /// In en, this message translates to:
  /// **'Doctor connected successfully.'**
  String get authDoctorConnected;

  /// No description provided for @authDoctorCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Account created, but the doctor code was invalid or expired.'**
  String get authDoctorCodeInvalid;

  /// No description provided for @authFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed.'**
  String get authFailed;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @chooseAccountType.
  ///
  /// In en, this message translates to:
  /// **'Choose account type'**
  String get chooseAccountType;

  /// No description provided for @patientDesc.
  ///
  /// In en, this message translates to:
  /// **'Upload and review X-rays'**
  String get patientDesc;

  /// No description provided for @doctorDesc.
  ///
  /// In en, this message translates to:
  /// **'Requires license approval'**
  String get doctorDesc;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @doYouHaveDoctor.
  ///
  /// In en, this message translates to:
  /// **'Do you have a doctor?'**
  String get doYouHaveDoctor;

  /// No description provided for @enterDoctorCodeSub.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent by your doctor.'**
  String get enterDoctorCodeSub;

  /// No description provided for @enterDoctorCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Doctor Code'**
  String get enterDoctorCode;

  /// No description provided for @emergencyName.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact Name'**
  String get emergencyName;

  /// No description provided for @emergencyPhone.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact Phone'**
  String get emergencyPhone;

  /// No description provided for @specialization.
  ///
  /// In en, this message translates to:
  /// **'Specialization'**
  String get specialization;

  /// No description provided for @licenseNumber.
  ///
  /// In en, this message translates to:
  /// **'Medical License Number'**
  String get licenseNumber;

  /// No description provided for @licensingBody.
  ///
  /// In en, this message translates to:
  /// **'Licensing Authority'**
  String get licensingBody;

  /// No description provided for @clinicName.
  ///
  /// In en, this message translates to:
  /// **'Clinic or Hospital Name'**
  String get clinicName;

  /// No description provided for @experienceYears.
  ///
  /// In en, this message translates to:
  /// **'Years of Experience'**
  String get experienceYears;

  /// No description provided for @professionalAddress.
  ///
  /// In en, this message translates to:
  /// **'Professional Address'**
  String get professionalAddress;

  /// No description provided for @doctorPendingWarning.
  ///
  /// In en, this message translates to:
  /// **'Doctor accounts remain pending until an admin reviews the license details.'**
  String get doctorPendingWarning;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Professional Bio'**
  String get bio;

  /// No description provided for @advancedAiDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Advanced AI X-ray Diagnosis'**
  String get advancedAiDiagnosis;

  /// No description provided for @systemStatusOnline.
  ///
  /// In en, this message translates to:
  /// **'System Status: Online'**
  String get systemStatusOnline;

  /// No description provided for @notProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get notProvided;

  /// No description provided for @otpEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number'**
  String get otpEnterPhone;

  /// No description provided for @otpPhoneShort.
  ///
  /// In en, this message translates to:
  /// **'Phone number is too short'**
  String get otpPhoneShort;

  /// No description provided for @otpMustLogin.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to send a verification code.'**
  String get otpMustLogin;

  /// No description provided for @otpSentWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent via WhatsApp!'**
  String get otpSentWhatsapp;

  /// No description provided for @otpNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get otpNetworkError;

  /// No description provided for @otpEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code you received.'**
  String get otpEnterCode;

  /// No description provided for @otpVerifiedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Phone number verified successfully!'**
  String get otpVerifiedSuccess;

  /// No description provided for @otpPhoneVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone Verification'**
  String get otpPhoneVerificationTitle;

  /// No description provided for @otpVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified!'**
  String get otpVerified;

  /// No description provided for @otpEnterTheCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the Code'**
  String get otpEnterTheCode;

  /// No description provided for @otpVerifyPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone Number'**
  String get otpVerifyPhoneNumber;

  /// No description provided for @otpVerifiedDesc.
  ///
  /// In en, this message translates to:
  /// **'Your phone number has been verified successfully.'**
  String get otpVerifiedDesc;

  /// No description provided for @otpSentDesc.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to your WhatsApp.\nIt expires in 5 minutes.'**
  String get otpSentDesc;

  /// No description provided for @otpSendDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter the patient\'s Egyptian phone number\nto send a WhatsApp verification code.'**
  String get otpSendDesc;

  /// No description provided for @otpEgyptianFormat.
  ///
  /// In en, this message translates to:
  /// **'Egyptian numbers are auto-formatted (e.g. 010… → +2010…)'**
  String get otpEgyptianFormat;

  /// No description provided for @otpSendCodeBtn.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get otpSendCodeBtn;

  /// No description provided for @otpChangeBtn.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get otpChangeBtn;

  /// No description provided for @otpVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get otpVerificationCode;

  /// No description provided for @otpVerifyBtn.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerifyBtn;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in '**
  String get otpResendIn;

  /// No description provided for @otpSeconds.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get otpSeconds;

  /// No description provided for @otpResendCodeBtn.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get otpResendCodeBtn;

  /// No description provided for @otpProceedDesc.
  ///
  /// In en, this message translates to:
  /// **'The phone number has been verified. You can now proceed.'**
  String get otpProceedDesc;

  /// No description provided for @otpDoneBtn.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get otpDoneBtn;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get profileTitle;

  /// No description provided for @profileAdminDesc.
  ///
  /// In en, this message translates to:
  /// **'View and manage your admin account'**
  String get profileAdminDesc;

  /// No description provided for @profilePatientDesc.
  ///
  /// In en, this message translates to:
  /// **'View and manage your personal information'**
  String get profilePatientDesc;

  /// No description provided for @profileCompletePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please complete your profile:'**
  String get profileCompletePrompt;

  /// No description provided for @profileAddName.
  ///
  /// In en, this message translates to:
  /// **'Add your name'**
  String get profileAddName;

  /// No description provided for @profileAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get profileAdmin;

  /// No description provided for @profilePatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get profilePatient;

  /// No description provided for @profilePersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get profilePersonalInfo;

  /// No description provided for @profilePersonalInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'Your personal and medical details'**
  String get profilePersonalInfoDesc;

  /// No description provided for @profileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// No description provided for @profilePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profilePhone;

  /// No description provided for @profileMedicalHistory.
  ///
  /// In en, this message translates to:
  /// **'Medical History'**
  String get profileMedicalHistory;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEdit;

  /// No description provided for @profileMedicalSummary.
  ///
  /// In en, this message translates to:
  /// **'Medical Summary'**
  String get profileMedicalSummary;

  /// No description provided for @profileMedicalSummaryDesc.
  ///
  /// In en, this message translates to:
  /// **'Overview of your medical data'**
  String get profileMedicalSummaryDesc;

  /// No description provided for @profileTotalXrays.
  ///
  /// In en, this message translates to:
  /// **'Total X-rays'**
  String get profileTotalXrays;

  /// No description provided for @profileLatestUpload.
  ///
  /// In en, this message translates to:
  /// **'Latest Upload'**
  String get profileLatestUpload;

  /// No description provided for @profileNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get profileNone;

  /// No description provided for @profileReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get profileReports;

  /// No description provided for @profileAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get profileAppearance;

  /// No description provided for @profileThemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred theme'**
  String get profileThemeDesc;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get profileSignOut;

  /// No description provided for @profileEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get profileEmailRequired;

  /// No description provided for @profilePassLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get profilePassLength;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get profileUpdateFailed;

  /// No description provided for @profileFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get profileFullName;

  /// No description provided for @profilePhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get profilePhoneNumber;

  /// No description provided for @profileNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get profileNewPassword;

  /// No description provided for @profileDob.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get profileDob;

  /// No description provided for @profileMedicalHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Medical history'**
  String get profileMedicalHistoryLabel;

  /// No description provided for @profileSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get profileSaveChanges;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @lightModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Always use light theme'**
  String get lightModeDesc;

  /// No description provided for @darkModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Always use dark theme'**
  String get darkModeDesc;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @systemDefaultDesc.
  ///
  /// In en, this message translates to:
  /// **'Follow device setting'**
  String get systemDefaultDesc;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get navUpload;

  /// No description provided for @navXrays.
  ///
  /// In en, this message translates to:
  /// **'X-Rays'**
  String get navXrays;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navAI.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get navAI;

  /// No description provided for @navPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get navPatients;

  /// No description provided for @navAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get navAdmin;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @latestHealthSummary.
  ///
  /// In en, this message translates to:
  /// **'Here\'s your latest health summary.'**
  String get latestHealthSummary;

  /// No description provided for @latestAIFindings.
  ///
  /// In en, this message translates to:
  /// **'Latest AI Findings'**
  String get latestAIFindings;

  /// No description provided for @yourRecentXray.
  ///
  /// In en, this message translates to:
  /// **'Your recent X-ray analysis'**
  String get yourRecentXray;

  /// No description provided for @viewFullReport.
  ///
  /// In en, this message translates to:
  /// **'View Full Report'**
  String get viewFullReport;

  /// No description provided for @healthRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Health Recommendations'**
  String get healthRecommendations;

  /// No description provided for @tipsForRecovery.
  ///
  /// In en, this message translates to:
  /// **'Tips for recovery'**
  String get tipsForRecovery;

  /// No description provided for @askAIAboutCondition.
  ///
  /// In en, this message translates to:
  /// **'Ask AI About My Condition'**
  String get askAIAboutCondition;

  /// No description provided for @restRecovery.
  ///
  /// In en, this message translates to:
  /// **'Rest & Recovery'**
  String get restRecovery;

  /// No description provided for @restRecoveryDesc.
  ///
  /// In en, this message translates to:
  /// **'Get plenty of rest and avoid strenuous activities.'**
  String get restRecoveryDesc;

  /// No description provided for @stayHydrated.
  ///
  /// In en, this message translates to:
  /// **'Stay Hydrated'**
  String get stayHydrated;

  /// No description provided for @stayHydratedDesc.
  ///
  /// In en, this message translates to:
  /// **'Drink plenty of water and fluids to help thin mucus.'**
  String get stayHydratedDesc;

  /// No description provided for @followUpCare.
  ///
  /// In en, this message translates to:
  /// **'Follow-up Care'**
  String get followUpCare;

  /// No description provided for @followUpCareDesc.
  ///
  /// In en, this message translates to:
  /// **'Take prescribed medications and attend all follow-up appointments.'**
  String get followUpCareDesc;

  /// No description provided for @aiHealthAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Health Assistant'**
  String get aiHealthAssistant;

  /// No description provided for @askAboutHealth.
  ///
  /// In en, this message translates to:
  /// **'Ask about your health'**
  String get askAboutHealth;

  /// No description provided for @aiMedicalAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Medical Assistant'**
  String get aiMedicalAssistant;

  /// No description provided for @askAboutXray.
  ///
  /// In en, this message translates to:
  /// **'Ask questions about X-ray analyses'**
  String get askAboutXray;

  /// No description provided for @quickQuestions.
  ///
  /// In en, this message translates to:
  /// **'Common Questions'**
  String get quickQuestions;

  /// No description provided for @quickAnswers.
  ///
  /// In en, this message translates to:
  /// **'Quick answers'**
  String get quickAnswers;

  /// No description provided for @aiCapabilities.
  ///
  /// In en, this message translates to:
  /// **'AI Capabilities'**
  String get aiCapabilities;

  /// No description provided for @healthTips.
  ///
  /// In en, this message translates to:
  /// **'Health Tips'**
  String get healthTips;

  /// No description provided for @connectToDoctor.
  ///
  /// In en, this message translates to:
  /// **'Connect to Doctor'**
  String get connectToDoctor;

  /// No description provided for @enterDoctorOtpDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code your doctor sent to your WhatsApp.'**
  String get enterDoctorOtpDesc;

  /// No description provided for @enterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Code'**
  String get enterCode;

  /// No description provided for @noScansYet.
  ///
  /// In en, this message translates to:
  /// **'No scans yet'**
  String get noScansYet;

  /// No description provided for @analyzed.
  ///
  /// In en, this message translates to:
  /// **'Analyzed'**
  String get analyzed;

  /// No description provided for @xraysLabel.
  ///
  /// In en, this message translates to:
  /// **'X-rays'**
  String get xraysLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @confidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidenceLabel;

  /// No description provided for @lastUpload.
  ///
  /// In en, this message translates to:
  /// **'Last upload'**
  String get lastUpload;

  /// No description provided for @uploadXrayTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload X-ray'**
  String get uploadXrayTitle;

  /// No description provided for @uploadXrayDescPatient.
  ///
  /// In en, this message translates to:
  /// **'Share your X-ray images with your doctor'**
  String get uploadXrayDescPatient;

  /// No description provided for @uploadXrayDescDoctor.
  ///
  /// In en, this message translates to:
  /// **'Upload for AI analysis'**
  String get uploadXrayDescDoctor;

  /// No description provided for @uploadImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get uploadImageLabel;

  /// No description provided for @uploadImageHint.
  ///
  /// In en, this message translates to:
  /// **'Select a clear X-ray image up to 10 MB'**
  String get uploadImageHint;

  /// No description provided for @uploadImageHintDoctor.
  ///
  /// In en, this message translates to:
  /// **'Drag and drop or click to select'**
  String get uploadImageHintDoctor;

  /// No description provided for @removeImage.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeImage;

  /// No description provided for @selectPatientLabel.
  ///
  /// In en, this message translates to:
  /// **'Select Patient'**
  String get selectPatientLabel;

  /// No description provided for @selectPatientHint.
  ///
  /// In en, this message translates to:
  /// **'Select a patient'**
  String get selectPatientHint;

  /// No description provided for @uploadingText.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploadingText;

  /// No description provided for @uploadSuccessMsg.
  ///
  /// In en, this message translates to:
  /// **'X-ray uploaded successfully! AI analysis will begin shortly.'**
  String get uploadSuccessMsg;

  /// No description provided for @uploadFailedMsg.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Check your connection.'**
  String get uploadFailedMsg;

  /// No description provided for @accountPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Pending Approval'**
  String get accountPendingTitle;

  /// No description provided for @accountPendingDesc.
  ///
  /// In en, this message translates to:
  /// **'Your account is awaiting admin verification. You will be able to upload X-rays once approved.'**
  String get accountPendingDesc;

  /// No description provided for @whatHappensNext.
  ///
  /// In en, this message translates to:
  /// **'What happens next?'**
  String get whatHappensNext;

  /// No description provided for @aiAnalysisTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis'**
  String get aiAnalysisTitle;

  /// No description provided for @aiAnalysisDesc.
  ///
  /// In en, this message translates to:
  /// **'Your X-ray will be analyzed by our AI system to detect any potential issues.'**
  String get aiAnalysisDesc;

  /// No description provided for @doctorReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor Review'**
  String get doctorReviewTitle;

  /// No description provided for @doctorReviewDesc.
  ///
  /// In en, this message translates to:
  /// **'A qualified doctor will review the AI results and provide their assessment.'**
  String get doctorReviewDesc;

  /// No description provided for @getResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Get Results'**
  String get getResultsTitle;

  /// No description provided for @getResultsDesc.
  ///
  /// In en, this message translates to:
  /// **'Receive a comprehensive report with findings and recommendations.'**
  String get getResultsDesc;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @manageAdminProfile.
  ///
  /// In en, this message translates to:
  /// **'View and manage your admin account'**
  String get manageAdminProfile;

  /// No description provided for @managePersonalProfile.
  ///
  /// In en, this message translates to:
  /// **'View and manage your personal information'**
  String get managePersonalProfile;

  /// No description provided for @manageDoctorProfile.
  ///
  /// In en, this message translates to:
  /// **'View and manage your professional information'**
  String get manageDoctorProfile;

  /// No description provided for @completeProfileMsg.
  ///
  /// In en, this message translates to:
  /// **'Please complete your profile:'**
  String get completeProfileMsg;

  /// No description provided for @updateInfoToContinue.
  ///
  /// In en, this message translates to:
  /// **'Update your information to continue using all features.'**
  String get updateInfoToContinue;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @professionalInfo.
  ///
  /// In en, this message translates to:
  /// **'Professional Information'**
  String get professionalInfo;

  /// No description provided for @profInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'Your professional credentials and details'**
  String get profInfoDesc;

  /// No description provided for @performanceOverview.
  ///
  /// In en, this message translates to:
  /// **'Performance Overview'**
  String get performanceOverview;

  /// No description provided for @perfOverviewDesc.
  ///
  /// In en, this message translates to:
  /// **'Your activity statistics'**
  String get perfOverviewDesc;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred theme'**
  String get appearanceDesc;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @deleteAccountPatient.
  ///
  /// In en, this message translates to:
  /// **'Delete your account and all data'**
  String get deleteAccountPatient;

  /// No description provided for @deleteAccountDoctor.
  ///
  /// In en, this message translates to:
  /// **'Delete your doctor account securely'**
  String get deleteAccountDoctor;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @dob.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dob;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @specialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get specialty;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @personalInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'Your personal details and medical history'**
  String get personalInfoDesc;

  /// No description provided for @medicalHistory.
  ///
  /// In en, this message translates to:
  /// **'Medical History'**
  String get medicalHistory;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @totalAnalyses.
  ///
  /// In en, this message translates to:
  /// **'Total Analyses'**
  String get totalAnalyses;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
