// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MediScan AI';

  @override
  String get success => 'Success';

  @override
  String get error => 'Error';

  @override
  String get warning => 'Warning';

  @override
  String get info => 'Info';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get loading => 'Loading...';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get logout => 'Logout';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get profileSettings => 'Profile Settings';

  @override
  String get adminConsole => 'Admin Console';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get notifications => 'Notifications';

  @override
  String get login => 'Login';

  @override
  String get signup => 'Sign Up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get home => 'Home';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get patients => 'Patients';

  @override
  String get doctors => 'Doctors';

  @override
  String get chats => 'Chats';

  @override
  String get xrays => 'X-Rays';

  @override
  String get upload => 'Upload';

  @override
  String get settings => 'Settings';

  @override
  String get diagnosing => 'Diagnosing...';

  @override
  String get completed => 'Completed';

  @override
  String get pending => 'Pending';

  @override
  String get reviewing => 'Reviewing';

  @override
  String get normal => 'Normal';

  @override
  String get pneumonia => 'Pneumonia';

  @override
  String get tuberculosis => 'Tuberculosis';

  @override
  String get authPleaseEnterEmailPass =>
      'Please enter your email and password.';

  @override
  String get authPleaseEnterName => 'Please enter your full name.';

  @override
  String get authPleaseEnterPhone => 'Please enter your phone number.';

  @override
  String get authPassLength => 'Password must be at least 8 characters.';

  @override
  String get authPassMismatch => 'Passwords do not match.';

  @override
  String get authPleaseEnterDob => 'Please enter your date of birth.';

  @override
  String get authDoctorDetailsRequired =>
      'Please complete your doctor verification details.';

  @override
  String get authDoctorConnected => 'Doctor connected successfully.';

  @override
  String get authDoctorCodeInvalid =>
      'Account created, but the doctor code was invalid or expired.';

  @override
  String get authFailed => 'Authentication failed.';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get getStarted => 'Get Started';

  @override
  String get chooseAccountType => 'Choose account type';

  @override
  String get patientDesc => 'Upload and review X-rays';

  @override
  String get doctorDesc => 'Requires license approval';

  @override
  String get fullName => 'Full Name';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get emailAddress => 'Email Address';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get gender => 'Gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get other => 'Other';

  @override
  String get dateOfBirth => 'Date of Birth';

  @override
  String get city => 'City';

  @override
  String get country => 'Country';

  @override
  String get doYouHaveDoctor => 'Do you have a doctor?';

  @override
  String get enterDoctorCodeSub => 'Enter the code sent by your doctor.';

  @override
  String get enterDoctorCode => 'Enter Doctor Code';

  @override
  String get emergencyName => 'Emergency Contact Name';

  @override
  String get emergencyPhone => 'Emergency Contact Phone';

  @override
  String get specialization => 'Specialization';

  @override
  String get licenseNumber => 'Medical License Number';

  @override
  String get licensingBody => 'Licensing Authority';

  @override
  String get clinicName => 'Clinic or Hospital Name';

  @override
  String get experienceYears => 'Years of Experience';

  @override
  String get professionalAddress => 'Professional Address';

  @override
  String get doctorPendingWarning =>
      'Doctor accounts remain pending until an admin reviews the license details.';

  @override
  String get bio => 'Professional Bio';

  @override
  String get advancedAiDiagnosis => 'Advanced AI X-ray Diagnosis';

  @override
  String get systemStatusOnline => 'System Status: Online';

  @override
  String get notProvided => 'Not provided';

  @override
  String get otpEnterPhone => 'Enter a phone number';

  @override
  String get otpPhoneShort => 'Phone number is too short';

  @override
  String get otpMustLogin =>
      'You must be logged in to send a verification code.';

  @override
  String get otpSentWhatsapp => 'Verification code sent via WhatsApp!';

  @override
  String get otpNetworkError => 'Network error. Please check your connection.';

  @override
  String get otpEnterCode => 'Enter the 6-digit code you received.';

  @override
  String get otpVerifiedSuccess => 'Phone number verified successfully!';

  @override
  String get otpPhoneVerificationTitle => 'Phone Verification';

  @override
  String get otpVerified => 'Verified!';

  @override
  String get otpEnterTheCode => 'Enter the Code';

  @override
  String get otpVerifyPhoneNumber => 'Verify Phone Number';

  @override
  String get otpVerifiedDesc =>
      'Your phone number has been verified successfully.';

  @override
  String get otpSentDesc =>
      'We sent a 6-digit code to your WhatsApp.\nIt expires in 5 minutes.';

  @override
  String get otpSendDesc =>
      'Enter the patient\'s Egyptian phone number\nto send a WhatsApp verification code.';

  @override
  String get otpEgyptianFormat =>
      'Egyptian numbers are auto-formatted (e.g. 010… → +2010…)';

  @override
  String get otpSendCodeBtn => 'Send Code';

  @override
  String get otpChangeBtn => 'Change';

  @override
  String get otpVerificationCode => 'Verification Code';

  @override
  String get otpVerifyBtn => 'Verify';

  @override
  String get otpResendIn => 'Resend code in ';

  @override
  String get otpSeconds => 's';

  @override
  String get otpResendCodeBtn => 'Resend Code';

  @override
  String get otpProceedDesc =>
      'The phone number has been verified. You can now proceed.';

  @override
  String get otpDoneBtn => 'Done';

  @override
  String get profileTitle => 'My Profile';

  @override
  String get profileAdminDesc => 'View and manage your admin account';

  @override
  String get profilePatientDesc => 'View and manage your personal information';

  @override
  String get profileCompletePrompt => 'Please complete your profile:';

  @override
  String get profileAddName => 'Add your name';

  @override
  String get profileAdmin => 'Admin';

  @override
  String get profilePatient => 'Patient';

  @override
  String get profilePersonalInfo => 'Personal Information';

  @override
  String get profilePersonalInfoDesc => 'Your personal and medical details';

  @override
  String get profileEmail => 'Email';

  @override
  String get profilePhone => 'Phone';

  @override
  String get profileMedicalHistory => 'Medical History';

  @override
  String get profileEdit => 'Edit Profile';

  @override
  String get profileMedicalSummary => 'Medical Summary';

  @override
  String get profileMedicalSummaryDesc => 'Overview of your medical data';

  @override
  String get profileTotalXrays => 'Total X-rays';

  @override
  String get profileLatestUpload => 'Latest Upload';

  @override
  String get profileNone => 'None';

  @override
  String get profileReports => 'Reports';

  @override
  String get profileAppearance => 'Appearance';

  @override
  String get profileThemeDesc => 'Choose your preferred theme';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String get profileEmailRequired => 'Email is required.';

  @override
  String get profilePassLength => 'Password must be at least 8 characters.';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get profileUpdateFailed => 'Failed to update profile';

  @override
  String get profileFullName => 'Full name';

  @override
  String get profilePhoneNumber => 'Phone number';

  @override
  String get profileNewPassword => 'New password';

  @override
  String get profileDob => 'Date of birth';

  @override
  String get profileMedicalHistoryLabel => 'Medical history';

  @override
  String get profileSaveChanges => 'Save Changes';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get lightModeDesc => 'Always use light theme';

  @override
  String get darkModeDesc => 'Always use dark theme';

  @override
  String get systemDefault => 'System Default';

  @override
  String get systemDefaultDesc => 'Follow device setting';

  @override
  String get navHome => 'Home';

  @override
  String get navUpload => 'Upload';

  @override
  String get navXrays => 'X-Rays';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profile';

  @override
  String get navAI => 'AI';

  @override
  String get navPatients => 'Patients';

  @override
  String get navAdmin => 'Admin';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get latestHealthSummary => 'Here\'s your latest health summary.';

  @override
  String get latestAIFindings => 'Latest AI Findings';

  @override
  String get yourRecentXray => 'Your recent X-ray analysis';

  @override
  String get viewFullReport => 'View Full Report';

  @override
  String get healthRecommendations => 'Health Recommendations';

  @override
  String get tipsForRecovery => 'Tips for recovery';

  @override
  String get askAIAboutCondition => 'Ask AI About My Condition';

  @override
  String get restRecovery => 'Rest & Recovery';

  @override
  String get restRecoveryDesc =>
      'Get plenty of rest and avoid strenuous activities.';

  @override
  String get stayHydrated => 'Stay Hydrated';

  @override
  String get stayHydratedDesc =>
      'Drink plenty of water and fluids to help thin mucus.';

  @override
  String get followUpCare => 'Follow-up Care';

  @override
  String get followUpCareDesc =>
      'Take prescribed medications and attend all follow-up appointments.';

  @override
  String get aiHealthAssistant => 'AI Health Assistant';

  @override
  String get askAboutHealth => 'Ask about your health';

  @override
  String get aiMedicalAssistant => 'AI Medical Assistant';

  @override
  String get askAboutXray => 'Ask questions about X-ray analyses';

  @override
  String get quickQuestions => 'Common Questions';

  @override
  String get quickAnswers => 'Quick answers';

  @override
  String get aiCapabilities => 'AI Capabilities';

  @override
  String get healthTips => 'Health Tips';

  @override
  String get connectToDoctor => 'Connect to Doctor';

  @override
  String get enterDoctorOtpDesc =>
      'Enter the 6-digit code your doctor sent to your WhatsApp.';

  @override
  String get enterCode => 'Enter Code';

  @override
  String get noScansYet => 'No scans yet';

  @override
  String get analyzed => 'Analyzed';

  @override
  String get xraysLabel => 'X-rays';

  @override
  String get statusLabel => 'Status';

  @override
  String get confidenceLabel => 'Confidence';

  @override
  String get lastUpload => 'Last upload';

  @override
  String get uploadXrayTitle => 'Upload X-ray';

  @override
  String get uploadXrayDescPatient =>
      'Share your X-ray images with your doctor';

  @override
  String get uploadXrayDescDoctor => 'Upload for AI analysis';

  @override
  String get uploadImageLabel => 'Upload Image';

  @override
  String get uploadImageHint => 'Select a clear X-ray image up to 10 MB';

  @override
  String get uploadImageHintDoctor => 'Drag and drop or click to select';

  @override
  String get removeImage => 'Remove';

  @override
  String get selectPatientLabel => 'Select Patient';

  @override
  String get selectPatientHint => 'Select a patient';

  @override
  String get uploadingText => 'Uploading...';

  @override
  String get uploadSuccessMsg =>
      'X-ray uploaded successfully! AI analysis will begin shortly.';

  @override
  String get uploadFailedMsg => 'Upload failed. Check your connection.';

  @override
  String get accountPendingTitle => 'Account Pending Approval';

  @override
  String get accountPendingDesc =>
      'Your account is awaiting admin verification. You will be able to upload X-rays once approved.';

  @override
  String get whatHappensNext => 'What happens next?';

  @override
  String get aiAnalysisTitle => 'AI Analysis';

  @override
  String get aiAnalysisDesc =>
      'Your X-ray will be analyzed by our AI system to detect any potential issues.';

  @override
  String get doctorReviewTitle => 'Doctor Review';

  @override
  String get doctorReviewDesc =>
      'A qualified doctor will review the AI results and provide their assessment.';

  @override
  String get getResultsTitle => 'Get Results';

  @override
  String get getResultsDesc =>
      'Receive a comprehensive report with findings and recommendations.';

  @override
  String get myProfile => 'My Profile';

  @override
  String get manageAdminProfile => 'View and manage your admin account';

  @override
  String get managePersonalProfile =>
      'View and manage your personal information';

  @override
  String get manageDoctorProfile =>
      'View and manage your professional information';

  @override
  String get completeProfileMsg => 'Please complete your profile:';

  @override
  String get updateInfoToContinue =>
      'Update your information to continue using all features.';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get professionalInfo => 'Professional Information';

  @override
  String get profInfoDesc => 'Your professional credentials and details';

  @override
  String get performanceOverview => 'Performance Overview';

  @override
  String get perfOverviewDesc => 'Your activity statistics';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceDesc => 'Choose your preferred theme';

  @override
  String get account => 'Account';

  @override
  String get deleteAccountPatient => 'Delete your account and all data';

  @override
  String get deleteAccountDoctor => 'Delete your doctor account securely';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get signOut => 'Sign Out';

  @override
  String get dob => 'Date of Birth';

  @override
  String get notSet => 'Not set';

  @override
  String get specialty => 'Specialty';

  @override
  String get personalInformation => 'Personal Information';

  @override
  String get personalInfoDesc => 'Your personal details and medical history';

  @override
  String get medicalHistory => 'Medical History';

  @override
  String get phone => 'Phone';

  @override
  String get totalAnalyses => 'Total Analyses';

  @override
  String get reports => 'Reports';
}
