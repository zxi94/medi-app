import os

def replace_in_file(path, old, new):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace(old, new)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

flutter_dir = 'flutter/lib/screens/auth'
d_upload = os.path.join(flutter_dir, 'doctor/doctor_upload.dart')

replace_in_file(d_upload, "const SectionCard(\n              title: 'What happens next?',", "SectionCard(\n              title: loc?.whatHappensNext ?? 'What happens next?',")
replace_in_file(d_upload, "title: 'What happens next?',", "title: loc?.whatHappensNext ?? 'What happens next?',")
replace_in_file(d_upload, "title: 'AI Analysis',", "title: loc?.aiAnalysisTitle ?? 'AI Analysis',")
replace_in_file(d_upload, "'Your X-ray will be analyzed by our AI system to detect any potential issues.'", "loc?.aiAnalysisDesc ?? 'Your X-ray will be analyzed by our AI system to detect any potential issues.'")
replace_in_file(d_upload, "title: 'Doctor Review',", "title: loc?.doctorReviewTitle ?? 'Doctor Review',")
replace_in_file(d_upload, "'A qualified doctor will review the AI results and provide their assessment.'", "loc?.doctorReviewDesc ?? 'A qualified doctor will review the AI results and provide their assessment.'")
replace_in_file(d_upload, "title: 'Get Results',", "title: loc?.getResultsTitle ?? 'Get Results',")
replace_in_file(d_upload, "'Receive a comprehensive report with findings and recommendations.'", "loc?.getResultsDesc ?? 'Receive a comprehensive report with findings and recommendations.'")

# doctor_profile.dart
d_profile = os.path.join(flutter_dir, 'doctor/doctor_profile.dart')
replace_in_file(d_profile, "Text('My Profile',", "Text(AppLocalizations.of(context)?.myProfile ?? 'My Profile',")
replace_in_file(d_profile, "'View and manage your professional information'", "AppLocalizations.of(context)?.manageDoctorProfile ?? 'View and manage your professional information'")
replace_in_file(d_profile, "title: 'Professional Information',", "title: AppLocalizations.of(context)?.professionalInfo ?? 'Professional Information',")
replace_in_file(d_profile, "description: 'Your professional credentials and details'", "description: AppLocalizations.of(context)?.profInfoDesc ?? 'Your professional credentials and details'")
replace_in_file(d_profile, "title: 'Performance Overview',", "title: AppLocalizations.of(context)?.performanceOverview ?? 'Performance Overview',")
replace_in_file(d_profile, "description: 'Your activity statistics'", "description: AppLocalizations.of(context)?.perfOverviewDesc ?? 'Your activity statistics'")
replace_in_file(d_profile, "title: 'Appearance',", "title: AppLocalizations.of(context)?.appearance ?? 'Appearance',")
replace_in_file(d_profile, "description: 'Choose your preferred theme'", "description: AppLocalizations.of(context)?.appearanceDesc ?? 'Choose your preferred theme'")
replace_in_file(d_profile, "title: 'Account',", "title: AppLocalizations.of(context)?.account ?? 'Account',")
replace_in_file(d_profile, "'Delete your doctor account securely'", "AppLocalizations.of(context)?.deleteAccountDoctor ?? 'Delete your doctor account securely'")
replace_in_file(d_profile, "label: Text('Delete Account',", "label: Text(AppLocalizations.of(context)?.deleteAccount ?? 'Delete Account',")
replace_in_file(d_profile, "label: Text('Sign Out',", "label: Text(AppLocalizations.of(context)?.signOut ?? 'Sign Out',")
replace_in_file(d_profile, "label: 'Full Name',", "label: AppLocalizations.of(context)?.fullName ?? 'Full Name',")
replace_in_file(d_profile, "label: 'Email',", "label: AppLocalizations.of(context)?.email ?? 'Email',")
replace_in_file(d_profile, "label: 'Specialty',", "label: AppLocalizations.of(context)?.specialty ?? 'Specialty',")
replace_in_file(d_profile, "label: 'Total Analyses',", "label: AppLocalizations.of(context)?.totalAnalyses ?? 'Total Analyses',")
replace_in_file(d_profile, "label: 'Reports',", "label: AppLocalizations.of(context)?.reports ?? 'Reports',")
replace_in_file(d_profile, "label: 'Pending',", "label: AppLocalizations.of(context)?.pending ?? 'Pending',")
replace_in_file(d_profile, "value: 'Not set',", "value: AppLocalizations.of(context)?.notSet ?? 'Not set',")

print('Done replacing doctor_profile.dart')

# patient_profile.dart
p_profile = os.path.join(flutter_dir, 'patient/patient_profile.dart')
replace_in_file(p_profile, "Text('My Profile',", "Text(AppLocalizations.of(context)?.myProfile ?? 'My Profile',")
replace_in_file(p_profile, "'View and manage your admin account'", "AppLocalizations.of(context)?.manageAdminProfile ?? 'View and manage your admin account'")
replace_in_file(p_profile, "'View and manage your personal information'", "AppLocalizations.of(context)?.managePersonalProfile ?? 'View and manage your personal information'")
replace_in_file(p_profile, "Text('Please complete your profile:',", "Text(AppLocalizations.of(context)?.completeProfileMsg ?? 'Please complete your profile:',")
replace_in_file(p_profile, "Text('Update your information to continue using all features.',", "Text(AppLocalizations.of(context)?.updateInfoToContinue ?? 'Update your information to continue using all features.',")
replace_in_file(p_profile, "label: Text('Edit Profile',", "label: Text(AppLocalizations.of(context)?.editProfile ?? 'Edit Profile',")
replace_in_file(p_profile, "title: 'Personal Information',", "title: AppLocalizations.of(context)?.personalInformation ?? 'Personal Information',")
replace_in_file(p_profile, "description: 'Your personal details and medical history'", "description: AppLocalizations.of(context)?.personalInfoDesc ?? 'Your personal details and medical history'")
replace_in_file(p_profile, "title: 'Account',", "title: AppLocalizations.of(context)?.account ?? 'Account',")
replace_in_file(p_profile, "'Delete your account and all data'", "AppLocalizations.of(context)?.deleteAccountPatient ?? 'Delete your account and all data'")
replace_in_file(p_profile, "label: Text('Delete Account',", "label: Text(AppLocalizations.of(context)?.deleteAccount ?? 'Delete Account',")
replace_in_file(p_profile, "label: Text('Sign Out',", "label: Text(AppLocalizations.of(context)?.signOut ?? 'Sign Out',")
replace_in_file(p_profile, "title: 'Appearance',", "title: AppLocalizations.of(context)?.appearance ?? 'Appearance',")
replace_in_file(p_profile, "description: 'Choose your preferred theme'", "description: AppLocalizations.of(context)?.appearanceDesc ?? 'Choose your preferred theme'")

replace_in_file(p_profile, "label: 'Full Name',", "label: AppLocalizations.of(context)?.fullName ?? 'Full Name',")
replace_in_file(p_profile, "label: 'Gender',", "label: AppLocalizations.of(context)?.gender ?? 'Gender',")
replace_in_file(p_profile, "label: 'Date of Birth',", "label: AppLocalizations.of(context)?.dob ?? 'Date of Birth',")
replace_in_file(p_profile, "label: 'Email',", "label: AppLocalizations.of(context)?.email ?? 'Email',")
replace_in_file(p_profile, "label: 'Phone',", "label: AppLocalizations.of(context)?.phone ?? 'Phone',")
replace_in_file(p_profile, "value: 'Not set',", "value: AppLocalizations.of(context)?.notSet ?? 'Not set',")
replace_in_file(p_profile, "label: 'Medical History',", "label: AppLocalizations.of(context)?.medicalHistory ?? 'Medical History',")

print('Done replacing patient_profile.dart')
