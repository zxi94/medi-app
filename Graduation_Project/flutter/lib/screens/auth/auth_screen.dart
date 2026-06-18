import 'package:mediscan_ai/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/alert_utils.dart';
import 'admin/admin_dashboard_view.dart';
import 'doctor/doctor_main.dart';
import 'patient/patient_main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignIn = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _specializationCtrl = TextEditingController();
  final _dobController = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _licensingBodyCtrl = TextEditingController();
  final _professionalAddressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _doctorCodeCtrl = TextEditingController();
  String _gender = 'other';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _signupRole = 'patient';
  bool _hasDoctor = false;

  AppLocalizations get loc => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPassController.dispose();
    _phoneCtrl.dispose();
    _specializationCtrl.dispose();
    _dobController.dispose();
    _licenseCtrl.dispose();
    _licensingBodyCtrl.dispose();
    _professionalAddressCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _clinicCtrl.dispose();
    _experienceCtrl.dispose();
    _bioCtrl.dispose();
    _doctorCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(loc.authPleaseEnterEmailPass);
      return;
    }

    if (!_isSignIn && _nameController.text.trim().isEmpty) {
      _showMessage(loc.authPleaseEnterName);
      return;
    }

    if (!_isSignIn && _phoneCtrl.text.trim().isEmpty) {
      _showMessage(loc.authPleaseEnterPhone);
      return;
    }

    if (!_isSignIn && password.length < 8) {
      _showMessage(loc.authPassLength);
      return;
    }

    if (!_isSignIn && password != _confirmPassController.text) {
      _showMessage(loc.authPassMismatch);
      return;
    }

    if (!_isSignIn) {
      if (_dobController.text.trim().isEmpty) {
        _showMessage(loc.authPleaseEnterDob);
        return;
      }
      if (_signupRole == 'doctor') {
        if (_specializationCtrl.text.trim().isEmpty ||
            _licenseCtrl.text.trim().isEmpty ||
            _licensingBodyCtrl.text.trim().isEmpty ||
            _clinicCtrl.text.trim().isEmpty ||
            _professionalAddressCtrl.text.trim().isEmpty) {
          _showMessage(loc.authDoctorDetailsRequired);
          return;
        }
      }
    }

    final patientInfo = [
      'Phone: ${_phoneCtrl.text.trim()}',
      'City: ${_cityCtrl.text.trim().isEmpty ? loc.notProvided : _cityCtrl.text.trim()}',
      'Country: ${_countryCtrl.text.trim().isEmpty ? loc.notProvided : _countryCtrl.text.trim()}',
      'Emergency contact: ${_emergencyNameCtrl.text.trim().isEmpty ? loc.notProvided : _emergencyNameCtrl.text.trim()}',
      'Emergency phone: ${_emergencyPhoneCtrl.text.trim().isEmpty ? loc.notProvided : _emergencyPhoneCtrl.text.trim()}',
    ].join('\n');

    final doctorVerification = [
      'Phone: ${_phoneCtrl.text.trim()}',
      'Specialty: ${_specializationCtrl.text.trim()}',
      'License: ${_licenseCtrl.text.trim()}',
      'Authority: ${_licensingBodyCtrl.text.trim()}',
      'Clinic/Hospital: ${_clinicCtrl.text.trim()}',
      'Experience: ${_experienceCtrl.text.trim().isEmpty ? loc.notProvided : _experienceCtrl.text.trim()} years',
      'Professional address: ${_professionalAddressCtrl.text.trim()}',
      'City: ${_cityCtrl.text.trim().isEmpty ? loc.notProvided : _cityCtrl.text.trim()}',
      'Country: ${_countryCtrl.text.trim().isEmpty ? loc.notProvided : _countryCtrl.text.trim()}',
      'Bio: ${_bioCtrl.text.trim().isEmpty ? loc.notProvided : _bioCtrl.text.trim()}',
    ].join('\n');

    final ok = _isSignIn
        ? await auth.login(email: email, password: password)
        : await auth.signup(
            name: _nameController.text.trim(),
            email: email,
            password: password,
            phone: _phoneCtrl.text.trim(),
            role: _signupRole,
            gender: _gender,
            dob: _dobController.text.trim(),
            medicalHistory: _signupRole == 'patient' ? patientInfo : null,
            specialization: _signupRole == 'doctor'
                ? _specializationCtrl.text.trim()
                : null,
            medicalCertificate:
                _signupRole == 'doctor' ? doctorVerification : null,
          );

    if (!mounted) return;

    if (!ok) {
      _showMessage(auth.errorMessage ?? loc.authFailed);
      return;
    }

    if (!_isSignIn &&
        _signupRole == 'patient' &&
        _hasDoctor &&
        _doctorCodeCtrl.text.trim().isNotEmpty &&
        auth.token != null) {
      try {
        await ChatService().verifyConnection(
          token: auth.token!,
          code: _doctorCodeCtrl.text.trim(),
        );
        _showMessage(loc.authDoctorConnected, isError: false);
      } catch (_) {
        _showMessage(loc.authDoctorCodeInvalid, isError: true);
      }
    }

    final userRole = auth.role?.toUpperCase() ?? '';
    if (userRole == 'ADMIN') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardView()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainUserNavigationView()),
      );
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    if (isError) {
      AlertUtils.showError(context, message);
    } else {
      AlertUtils.showSuccess(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Gradient (Light Mode Only)
          if (!isDark)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE0F7FA),
                      Colors.white,
                      Color(0xFFE0F7FA)
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text('AI',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            )),
                      ),
                      const SizedBox(height: 20),
                      Text('MediScan AI',
                          style: GoogleFonts.dmSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: theme.textTheme.headlineLarge?.color,
                          )),
                      const SizedBox(height: 8),
                      Text(
                        loc.advancedAiDiagnosis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Auth Card
                      Container(
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(24),
                          border:
                              theme.cardTheme.shape is RoundedRectangleBorder
                                  ? Border.fromBorderSide((theme.cardTheme.shape
                                          as RoundedRectangleBorder)
                                      .side)
                                  : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.3 : 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            // Custom Tab Switcher
                            Container(
                              height: 48,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  _TabButton(
                                    label: loc.signIn,
                                    isActive: _isSignIn,
                                    onTap: () =>
                                        setState(() => _isSignIn = true),
                                  ),
                                  _TabButton(
                                    label: loc.signUp,
                                    isActive: !_isSignIn,
                                    onTap: () =>
                                        setState(() => _isSignIn = false),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            if (!_isSignIn) ...[
                              Text(
                                loc.chooseAccountType,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _RoleChoiceCard(
                                      title: loc.patients,
                                      subtitle: loc.patientDesc,
                                      icon: Icons.personal_injury_outlined,
                                      selected: _signupRole == 'patient',
                                      onTap: () => setState(
                                          () => _signupRole = 'patient'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _RoleChoiceCard(
                                      title: loc.doctors,
                                      subtitle: loc.doctorDesc,
                                      icon: Icons.medical_services_outlined,
                                      selected: _signupRole == 'doctor',
                                      onTap: () => setState(
                                          () => _signupRole = 'doctor'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _FormField(
                                label: loc.fullName,
                                controller: _nameController,
                                hint: 'John Doe',
                                icon: Icons.person_outline,
                                theme: theme,
                              ),
                              const SizedBox(height: 18),
                              _FormField(
                                label: loc.phoneNumber,
                                controller: _phoneCtrl,
                                hint: '+20 100 000 0000',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                theme: theme,
                              ),
                              const SizedBox(height: 18),
                            ],

                            _FormField(
                              label: loc.emailAddress,
                              controller: _emailController,
                              hint: 'example@email.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              theme: theme,
                            ),
                            const SizedBox(height: 18),

                            _PasswordField(
                              label: loc.password,
                              controller: _passwordController,
                              hint: '********',
                              obscure: _obscurePassword,
                              onToggle: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              theme: theme,
                            ),

                            if (!_isSignIn) ...[
                              const SizedBox(height: 18),
                              _PasswordField(
                                label: loc.confirmPassword,
                                controller: _confirmPassController,
                                hint: '********',
                                obscure: _obscureConfirm,
                                onToggle: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                                theme: theme,
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _gender,
                                      decoration: InputDecoration(
                                        labelText: loc.gender,
                                        prefixIcon:
                                            const Icon(Icons.wc_outlined),
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                            value: 'male',
                                            child: Text(loc.male)),
                                        DropdownMenuItem(
                                            value: 'female',
                                            child: Text(loc.female)),
                                        DropdownMenuItem(
                                            value: 'other',
                                            child: Text(loc.other)),
                                      ],
                                      onChanged: (v) => setState(
                                          () => _gender = v ?? 'other'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _FormField(
                                      label: loc.dateOfBirth,
                                      controller: _dobController,
                                      hint: 'YYYY-MM-DD',
                                      icon: Icons.cake_outlined,
                                      keyboardType: TextInputType.datetime,
                                      theme: theme,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: _FormField(
                                      label: loc.city,
                                      controller: _cityCtrl,
                                      hint: 'Cairo',
                                      icon: Icons.location_city_outlined,
                                      theme: theme,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _FormField(
                                      label: loc.country,
                                      controller: _countryCtrl,
                                      hint: 'Egypt',
                                      icon: Icons.public_outlined,
                                      theme: theme,
                                    ),
                                  ),
                                ],
                              ),
                              if (_signupRole == 'patient') ...[
                                const SizedBox(height: 18),
                                SwitchListTile(
                                  value: _hasDoctor,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    loc.doYouHaveDoctor,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    loc.enterDoctorCodeSub,
                                    style: GoogleFonts.dmSans(fontSize: 12),
                                  ),
                                  onChanged: (value) =>
                                      setState(() => _hasDoctor = value),
                                ),
                                if (_hasDoctor) ...[
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _doctorCodeCtrl,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    decoration: InputDecoration(
                                      labelText: loc.enterDoctorCode,
                                      counterText: '',
                                      prefixIcon:
                                          const Icon(Icons.verified_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                ],
                                TextField(
                                  controller: _emergencyNameCtrl,
                                  decoration: InputDecoration(
                                    labelText: loc.emergencyName,
                                    prefixIcon: const Icon(
                                        Icons.contact_phone_outlined),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: _emergencyPhoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: loc.emergencyPhone,
                                    prefixIcon: const Icon(
                                        Icons.phone_in_talk_outlined),
                                  ),
                                ),
                              ],
                              if (_signupRole == 'doctor') ...[
                                const SizedBox(height: 18),
                                TextField(
                                  controller: _specializationCtrl,
                                  decoration: InputDecoration(
                                    labelText: loc.specialization,
                                    prefixIcon: const Icon(
                                        Icons.medical_services_outlined),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: _licenseCtrl,
                                  decoration: InputDecoration(
                                    labelText: loc.licenseNumber,
                                    prefixIcon:
                                        const Icon(Icons.badge_outlined),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: _licensingBodyCtrl,
                                  decoration: InputDecoration(
                                    labelText: loc.licensingBody,
                                    prefixIcon: const Icon(
                                        Icons.verified_user_outlined),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: _clinicCtrl,
                                  decoration: InputDecoration(
                                    labelText: loc.clinicName,
                                    prefixIcon: const Icon(
                                        Icons.local_hospital_outlined),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: _experienceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: loc.experienceYears,
                                    prefixIcon:
                                        const Icon(Icons.timeline_outlined),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: _professionalAddressCtrl,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText: loc.professionalAddress,
                                    prefixIcon:
                                        const Icon(Icons.location_on_outlined),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  loc.doctorPendingWarning,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: _bioCtrl,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: loc.bio,
                                    prefixIcon:
                                        const Icon(Icons.description_outlined),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                              ],
                            ],

                            const SizedBox(height: 24),

                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                return SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed:
                                        auth.isLoading ? null : _handleAuth,
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: auth.isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            _isSignIn
                                                ? loc.signIn
                                                : loc.getStarted,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: AppTheme.success,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(loc.systemStatusOnline,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary,
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? theme.cardTheme.color : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppTheme.primary
                    : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              )),
        ),
      ),
    );
  }
}

class _RoleChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 108),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: selected ? AppTheme.primary : null),
                const Spacer(),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? AppTheme.primary : theme.disabledColor,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final ThemeData theme;

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.theme,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            )),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final ThemeData theme;

  const _PasswordField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            )),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}
