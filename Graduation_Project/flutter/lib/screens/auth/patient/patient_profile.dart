import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/app_user.dart';
import '../../../services/api_client.dart';
import '../../../services/xray_service.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../widgets/admin_badge.dart';
import '../../../widgets/shared_widgets.dart';
import '../../../widgets/theme_switcher.dart';
import '../../../utils/alert_utils.dart';
import '../auth_screen.dart';
import 'package:mediscan_ai/l10n/app_localizations.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _service = XrayService();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String? _error;

  AppLocalizations get loc => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    final token = context.read<AuthProvider>().token;
    final auth = context.read<AuthProvider>();
    if (auth.isAdmin) {
      setState(() => _isLoading = false);
      return;
    }
    if (token == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final stats = await _service.fetchMyStats(token);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final profileUser = auth.user;
    final isAdminProfile = auth.isAdmin;
    final txtSec = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final txtBody = theme.textTheme.bodyLarge?.color;
    final displayName = profileUser?.name ?? '';
    final displayEmail = profileUser?.email ?? '';
    final initials = profileUser?.initials ?? '?';
    final gender = profileUser?.gender;
    final phone = profileUser?.phone;
    final dob = profileUser?.dob;
    final medicalHistory = profileUser?.medicalHistory;
    final xrayCount = (_stats['xrayCount'] as num?)?.toInt() ?? 0;
    final latestDate = _stats['latestXray'] is Map<String, dynamic>
        ? _stats['latestXray']['upload_date'] as String?
        : null;

    final missingFields = <String>[];
    if (!isAdminProfile && displayName.isEmpty) missingFields.add('Full Name');
    if (!isAdminProfile &&
        (gender == null || gender.isEmpty || gender == 'other')) {
      missingFields.add('Gender');
    }
    if (!isAdminProfile && (dob == null || dob.isEmpty)) {
      missingFields.add('Date of Birth');
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const SessionAppTopBar(hideProfileMenu: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)?.myProfile ?? 'My Profile',
                style: GoogleFonts.dmSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.headlineLarge?.color)),
            const SizedBox(height: 4),
            Text(
                isAdminProfile
                    ? AppLocalizations.of(context)?.manageAdminProfile ?? 'View and manage your admin account'
                    : AppLocalizations.of(context)?.managePersonalProfile ?? 'View and manage your personal information',
                style: GoogleFonts.dmSans(fontSize: 14, color: txtSec)),
            const SizedBox(height: 20),
            if (missingFields.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 20, color: AppTheme.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context)?.completeProfileMsg ?? 'Please complete your profile:',
                              style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.warning)),
                          const SizedBox(height: 4),
                          ...missingFields.map((f) => Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('• $f',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 12, color: AppTheme.warning)),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
                ),
                child: Text(_error!,
                    style: GoogleFonts.dmSans(
                        color: AppTheme.error, fontWeight: FontWeight.w600)),
              ),
            SectionCard(
              title: '',
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  child: Text(initials,
                      style: GoogleFonts.dmSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary)),
                ),
                const SizedBox(height: 14),
                UserNameWithBadge(
                  name: displayName.isNotEmpty ? displayName : 'Add your name',
                  isAdmin: auth.isAdmin,
                  isLoading: auth.isLoading,
                  nameStyle: GoogleFonts.dmSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: displayName.isNotEmpty
                        ? txtBody
                        : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(displayEmail.isNotEmpty ? displayEmail.toUpperCase() : '',
                    style: GoogleFonts.dmSans(fontSize: 13, color: txtSec)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Badge(
                        label: isAdminProfile ? 'Admin' : 'Patient',
                        bg: isDark
                            ? theme.colorScheme.surfaceContainerHighest
                            : AppTheme.badgeBlue,
                        fg: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.badgeBlueFg),
                    const SizedBox(width: 8),
                    AdminBadge(
                        isAdmin: auth.isAdmin, isLoading: auth.isLoading),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppLocalizations.of(context)?.personalInformation ?? 'Personal Information',
              description: 'Your personal and medical details',
              child: Column(children: [
                _InfoTile(
                  icon: Icons.person_outline,
                  iconColor: AppTheme.primary,
                  label: AppLocalizations.of(context)?.fullName ?? 'Full Name',
                  value: displayName.isNotEmpty ? displayName : 'Not set',
                  missing: displayName.isEmpty,
                ),
                const SizedBox(height: 8),
                _InfoTile(
                  icon: Icons.email_outlined,
                  iconColor: AppTheme.primary,
                  label: AppLocalizations.of(context)?.email ?? 'Email',
                  value: displayEmail,
                ),
                const SizedBox(height: 8),
                if (!isAdminProfile) ...[
                  _InfoTile(
                    icon: Icons.phone_outlined,
                    iconColor: AppTheme.primary,
                    label: AppLocalizations.of(context)?.phone ?? 'Phone',
                    value:
                        (phone != null && phone.isNotEmpty) ? phone : 'Not set',
                    missing: phone == null || phone.isEmpty,
                  ),
                  const SizedBox(height: 8),
                  _InfoTile(
                    icon: Icons.female_outlined,
                    iconColor: const Color(0xFFEF5350),
                    label: AppLocalizations.of(context)?.gender ?? 'Gender',
                    value: (gender != null && gender != 'other')
                        ? gender[0].toUpperCase() + gender.substring(1)
                        : 'Not set',
                    missing:
                        gender == null || gender.isEmpty || gender == 'other',
                  ),
                  const SizedBox(height: 8),
                  _InfoTile(
                    icon: Icons.cake_outlined,
                    iconColor: AppTheme.warning,
                    label: AppLocalizations.of(context)?.dob ?? 'Date of Birth',
                    value: dob ?? 'Not set',
                    missing: dob == null || dob.isEmpty,
                  ),
                  if (medicalHistory != null && medicalHistory.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoTile(
                      icon: Icons.assignment_outlined,
                      iconColor: AppTheme.success,
                      label: AppLocalizations.of(context)?.medicalHistory ?? 'Medical History',
                      value: medicalHistory,
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _openEditProfile(context, profileUser, auth),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(AppLocalizations.of(context)?.editProfile ?? 'Edit Profile',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            if (!isAdminProfile) ...[
              SectionCard(
                title: 'Medical Summary',
                description: 'Overview of your medical data',
                padding: EdgeInsets.zero,
                child: _isLoading
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator()))
                    : Column(children: [
                        _StatRow(label: 'Total X-rays', value: '$xrayCount'),
                        Divider(height: 1, color: theme.dividerTheme.color),
                        _StatRow(
                            label: 'Latest Upload',
                            value: latestDate != null
                                ? _formatDate(latestDate)
                                : 'None'),
                        Divider(height: 1, color: theme.dividerTheme.color),
                        _StatRow(
                            label: 'Reports',
                            value: '${_stats['reportCount'] ?? 0}'),
                      ]),
              ),
              const SizedBox(height: 16),
            ],
            SectionCard(
              title: AppLocalizations.of(context)?.appearance ?? 'Appearance',
              description: AppLocalizations.of(context)?.appearanceDesc ?? 'Choose your preferred theme',
              child: ThemeSwitcher(),
            ),
            const SizedBox(height: 16),
            const _LanguageSelectorCard(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<AuthProvider>().logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (_) => false,
                  );
                },
                icon: const Icon(Icons.logout, size: 18, color: Colors.red),
                label: Text(AppLocalizations.of(context)?.signOut ?? 'Sign Out',
                    style: GoogleFonts.dmSans(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditProfile(
      BuildContext context, AppUser? profileUser, AuthProvider auth) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) =>
          _EditProfileDialog(user: profileUser, isAdmin: auth.isAdmin),
    );
    if (result == null) return;
    if ((result['email'] ?? '').trim().isEmpty) {
      AlertUtils.showError(context, loc.profileEmailRequired);
      return;
    }
    final newPassword = result['password']?.trim() ?? '';
    if (newPassword.isNotEmpty && newPassword.length < 8) {
      AlertUtils.showError(context, loc.profilePassLength);
      return;
    }
    final ok = await auth.updateProfile(
      name: result['name'],
      phone: result['phone'],
      email: result['email'],
      password: newPassword,
      gender: result['gender'],
      dob: result['dob'],
      medicalHistory: result['medicalHistory'],
    );
    if (!mounted) return;
    if (ok) {
      AlertUtils.showSuccess(context, loc.profileUpdated);
    } else {
      AlertUtils.showError(
          context, auth.errorMessage ?? loc.profileUpdateFailed);
    }
  }

  String _formatDate(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    return DateFormat.yMMMd().format(dt.toLocal());
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  final bool missing;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.missing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: missing
            ? AppTheme.warning.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: missing
            ? Border.all(color: AppTheme.warning.withValues(alpha: 0.25))
            : null,
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: missing
                        ? AppTheme.warning
                        : theme.textTheme.bodyLarge?.color)),
          ]),
        ),
        if (missing)
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: AppTheme.warning),
      ]),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 14,
                color: theme.brightness == Brightness.dark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary)),
        Text(value,
            style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary)),
      ]),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final AppUser? user;
  final bool isAdmin;

  const _EditProfileDialog({this.user, required this.isAdmin});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.user?.name ?? '');
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.user?.email ?? '');
  late final TextEditingController _phoneCtrl =
      TextEditingController(text: widget.user?.phone ?? '');
  final _passwordCtrl = TextEditingController();
  late final TextEditingController _medicalHistoryCtrl =
      TextEditingController(text: widget.user?.medicalHistory ?? '');
  late String _gender = widget.user?.gender ?? 'other';
  late final TextEditingController _dobCtrl =
      TextEditingController(text: widget.user?.dob ?? '');

  AppLocalizations get loc => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _dobCtrl.dispose();
    _medicalHistoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tryParseDob() ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      _dobCtrl.text = picked.toIso8601String().split('T').first;
      setState(() {});
    }
  }

  DateTime? _tryParseDob() {
    final t = _dobCtrl.text.trim();
    if (t.isEmpty) return null;
    return DateTime.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Edit Profile',
                        style: GoogleFonts.dmSans(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!widget.isAdmin) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              if (!widget.isAdmin) ...[
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.female_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _gender = v ?? 'other'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dobCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    prefixIcon: Icon(Icons.cake_outlined),
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _medicalHistoryCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Medical history',
                    prefixIcon: Icon(Icons.assignment_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'name': _nameCtrl.text.trim(),
                      'phone': _phoneCtrl.text.trim(),
                      'email': _emailCtrl.text.trim(),
                      'password': _passwordCtrl.text.trim(),
                      'gender': _gender,
                      'dob': _dobCtrl.text.trim(),
                      'medicalHistory': _medicalHistoryCtrl.text.trim(),
                    });
                  },
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );
}

// ──────────────────────────────────────────────────────────────────
// Language Selector Card
// ──────────────────────────────────────────────────────────────────

class _LanguageSelectorCard extends StatelessWidget {
  const _LanguageSelectorCard();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txtSec = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return SectionCard(
      title: 'Language',
      description: 'Choose your preferred language',
      child: Row(
        children: [
          Expanded(
            child: _LangOption(
              flag: '🇬🇧',
              label: 'English',
              isActive: lang.languageCode == 'en',
              onTap: () => lang.updateLanguage('en'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LangOption(
              flag: '🇸🇦',
              label: 'العربية',
              isActive: lang.languageCode == 'ar',
              onTap: () => lang.updateLanguage('ar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String flag;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LangOption({
    required this.flag,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppTheme.primary
                : (isDark ? AppTheme.darkBorderColor : AppTheme.borderColor),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? AppTheme.primary
                    : theme.textTheme.bodyLarge?.color,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 16, color: AppTheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}
