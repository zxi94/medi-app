import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/app_user.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../services/api_client.dart';
import '../../../services/xray_service.dart';
import '../../../utils/alert_utils.dart';
import '../../../widgets/admin_badge.dart';
import '../../../widgets/shared_widgets.dart';
import '../../../widgets/theme_switcher.dart';
import '../auth_screen.dart';
import 'package:mediscan_ai/l10n/app_localizations.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _service = XrayService();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String? _error;

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
    if (token == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final stats = await _service.fetchDoctorStats(token);
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final profileUser = auth.user;
    final txtSec = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final txtBody = theme.textTheme.bodyLarge?.color;
    final displayName = profileUser?.name ?? '';
    final displayEmail = profileUser?.email ?? '';
    final initials = profileUser?.initials ?? 'DR';
    final specialization = profileUser?.specialization;
    final verificationStatus = profileUser?.verificationStatus;

    final totalAnalyses = (_stats['totalAnalyses'] as num?)?.toInt() ?? 0;
    final totalReports = (_stats['totalReports'] as num?)?.toInt() ?? 0;
    final pendingCount = (_stats['pendingCount'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: SessionAppTopBar(hideProfileMenu: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)?.myProfile ?? 'My Profile',
                style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.headlineLarge?.color)),
            const SizedBox(height: 4),
            Text(AppLocalizations.of(context)?.manageDoctorProfile ?? 'View and manage your professional information',
                style: GoogleFonts.dmSans(fontSize: 14, color: txtSec)),
            const SizedBox(height: 20),
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
                  backgroundColor: AppTheme.primary,
                  child: Text(initials,
                      style: GoogleFonts.dmSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                const SizedBox(height: 16),
                UserNameWithBadge(
                  name: displayName.isNotEmpty ? displayName : 'Doctor',
                  isAdmin: auth.isAdmin,
                  isLoading: auth.isLoading,
                  nameStyle: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: displayName.isNotEmpty
                          ? txtBody
                          : AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(displayEmail.isNotEmpty ? displayEmail.toUpperCase() : '',
                    style: GoogleFonts.dmSans(fontSize: 13, color: txtSec)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _DarkBadge(
                        label: 'Doctor',
                        bg: theme.colorScheme.surfaceContainerHighest,
                        fg: txtBody ?? Colors.white),
                    const SizedBox(width: 8),
                    AdminBadge(
                        isAdmin: auth.isAdmin, isLoading: auth.isLoading),
                    if (verificationStatus != null) ...[
                      const SizedBox(width: 8),
                      _DarkBadge(
                        label: verificationStatus == 'approved'
                            ? 'Verified'
                            : verificationStatus,
                        bg: verificationStatus == 'approved'
                            ? AppTheme.statGreenBg
                            : AppTheme.warning.withValues(alpha: 0.15),
                        fg: verificationStatus == 'approved'
                            ? AppTheme.statGreenLabel
                            : AppTheme.warning,
                      ),
                    ],
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppLocalizations.of(context)?.professionalInfo ?? 'Professional Information',
              description: AppLocalizations.of(context)?.profInfoDesc ?? 'Your professional credentials and details',
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
                _InfoTile(
                  icon: Icons.medical_services_outlined,
                  iconColor: AppTheme.primary,
                  label: AppLocalizations.of(context)?.specialty ?? 'Specialty',
                  value: (specialization != null && specialization.isNotEmpty)
                      ? specialization
                      : 'Not set',
                  missing: specialization == null || specialization.isEmpty,
                ),
                if (displayName.isNotEmpty || specialization != null) ...[
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _openEditProfile(context, profileUser, auth),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text('Edit Profile',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppLocalizations.of(context)?.performanceOverview ?? 'Performance Overview',
              description: AppLocalizations.of(context)?.perfOverviewDesc ?? 'Your activity statistics',
              child: _isLoading
                  ? const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator()))
                  : Column(children: [
                      Row(children: [
                        Expanded(
                            child: _FigmaStatBlock(
                                label: AppLocalizations.of(context)?.totalAnalyses ?? 'Total Analyses',
                                value: '$totalAnalyses',
                                bg: AppTheme.statBlueBg,
                                valueFg: AppTheme.statBlueFg,
                                labelFg: AppTheme.statBlueLabel)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _FigmaStatBlock(
                                label: AppLocalizations.of(context)?.reports ?? 'Reports',
                                value: '$totalReports',
                                bg: AppTheme.statGreenBg,
                                valueFg: AppTheme.statGreenFg,
                                labelFg: AppTheme.statGreenLabel)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _FigmaStatBlock(
                                label: AppLocalizations.of(context)?.pending ?? 'Pending',
                                value: '$pendingCount',
                                bg: AppTheme.statPurpleBg,
                                valueFg: AppTheme.statPurpleFg,
                                labelFg: AppTheme.statPurpleLabel)),
                        const SizedBox(width: 12),
                        const Expanded(
                            child: _FigmaStatBlock(
                                label: 'Accuracy',
                                value: '98%',
                                bg: AppTheme.statOrangeBg,
                                valueFg: AppTheme.statOrangeFg,
                                labelFg: AppTheme.statOrangeLabel)),
                      ]),
                    ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppLocalizations.of(context)?.appearance ?? 'Appearance',
              description: AppLocalizations.of(context)?.appearanceDesc ?? 'Choose your preferred theme',
              child: ThemeSwitcher(),
            ),
            const SizedBox(height: 16),
            const _LanguageSelectorCard(),
            const SizedBox(height: 16),
            SectionCard(
              title: AppLocalizations.of(context)?.account ?? 'Account',
              description: AppLocalizations.of(context)?.deleteAccountDoctor ?? 'Delete your doctor account securely',
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _deleteAccountDialog(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(AppLocalizations.of(context)?.deleteAccount ?? 'Delete Account',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                  ),
                ),
              ),
            ),
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
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _EditDoctorProfileDialog(user: profileUser),
    );
    if (result == null) return;
    final ok = await auth.updateProfile(
      name: result['name'],
      email: result['email'],
      password: result['password'],
      specialization: result['specialization'],
    );
    if (!mounted) return;
    if (ok) {
      AlertUtils.showSuccess(context, 'Profile updated');
    } else {
      AlertUtils.showError(
          context, auth.errorMessage ?? 'Failed to update profile');
    }
  }

  Future<void> _deleteAccountDialog(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    final confirmed = await AlertUtils.showConfirmationDialog(
      context,
      title: 'Delete Account',
      content:
          'This will permanently delete your doctor account. Are you sure you want to proceed?',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true) return;

    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null) return;
    final ok = await auth.deleteAccount(password: password);
    if (!mounted) return;
    if (ok) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    } else {
      AlertUtils.showError(
          context, auth.errorMessage ?? 'Could not delete account');
    }
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

class _FigmaStatBlock extends StatelessWidget {
  final String label, value;
  final Color bg, valueFg, labelFg;

  const _FigmaStatBlock(
      {required this.label,
      required this.value,
      required this.bg,
      required this.valueFg,
      required this.labelFg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 14, color: labelFg)),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.dmSans(
                  fontSize: 24, fontWeight: FontWeight.w800, color: valueFg)),
        ]),
      );
}

class _DarkBadge extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _DarkBadge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      );
}

class _EditDoctorProfileDialog extends StatefulWidget {
  final AppUser? user;

  const _EditDoctorProfileDialog({this.user});

  @override
  State<_EditDoctorProfileDialog> createState() =>
      _EditDoctorProfileDialogState();
}

class _EditDoctorProfileDialogState extends State<_EditDoctorProfileDialog> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.user?.name ?? '');
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.user?.email ?? '');
  final _passwordCtrl = TextEditingController();
  late final TextEditingController _specializationCtrl =
      TextEditingController(text: widget.user?.specialization ?? '');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _specializationCtrl.dispose();
    super.dispose();
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
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
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
              TextField(
                controller: _specializationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Specialization',
                  prefixIcon: Icon(Icons.medical_services_outlined),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'name': _nameCtrl.text.trim(),
                      'email': _emailCtrl.text.trim(),
                      'password': _passwordCtrl.text.trim(),
                      'specialization': _specializationCtrl.text.trim(),
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

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'This removes your account and professional profile. Confirm with your password to continue.'),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final password = _passwordCtrl.text;
            if (password.isNotEmpty) {
              Navigator.pop(context, password);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          child: const Text('Delete Account'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Language Selector Card (shared between doctor & patient profiles)
// ──────────────────────────────────────────────────────────────────

class _LanguageSelectorCard extends StatelessWidget {
  const _LanguageSelectorCard();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
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
