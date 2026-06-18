import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mediscan_ai/l10n/app_localizations.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/api_client.dart';
import '../../../services/chat_service.dart';
import '../../../theme/app_theme.dart';
import '../../shared/care_chat_screen.dart';
import '../admin/admin_main.dart';
import '../patient/patient_dashboard.dart';
import 'patient_xrays.dart';
import 'patient_upload.dart';
import 'patient_profile.dart';
import 'patient_chatbot.dart';

class PatientMainScreen extends StatefulWidget {
  const PatientMainScreen({super.key});

  @override
  State<PatientMainScreen> createState() => _PatientMainScreenState();
}

class _PatientMainScreenState extends State<PatientMainScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _chatRefreshKey = 0;
  final _chatService = ChatService();
  bool _checkingPending = false;

  List<Widget> _buildScreens(bool isAdmin) => [
        const PatientDashboard(),
        const PatientUploadScreen(),
        const PatientXraysScreen(),
        CareChatScreen(refreshKey: _chatRefreshKey),
        const PatientChatbotScreen(),
        const PatientProfileScreen(),
        if (isAdmin) const AdminMainScreen(),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingOtp());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingOtp();
    }
  }

  /// Called on login and every app foreground resume.
  /// If a pending OTP connection exists, shows the non-dismissible modal.
  Future<void> _checkPendingOtp() async {
    if (_checkingPending || !mounted) return;
    _checkingPending = true;
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;
      final pending = await _chatService.fetchPendingConnection(token);
      if (!mounted || pending == null) return;
      await _showOtpModal(pending);
    } finally {
      _checkingPending = false;
    }
  }

  /// Shows a non-dismissible full-screen modal that the patient uses to
  /// confirm the doctor's connection request by entering their WhatsApp OTP.
  Future<void> _showOtpModal(PendingConnection pending) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Non-dismissible
      builder: (_) => _PatientOtpConnectionModal(
        pending: pending,
        chatService: _chatService,
      ),
    );
    if (confirmed == true && mounted) {
      // Navigate patient directly to the Chat tab
      setState(() {
        _currentIndex = 3;
        _chatRefreshKey++;
      });
    }
  }

  void _selectIndex(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 3) _chatRefreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final screens = _buildScreens(isAdmin);

    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBg : Colors.white,
          border: Border(
              top: BorderSide(
                  color: isDark
                      ? AppTheme.darkBorderColor
                      : AppTheme.borderColor)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 12,
                offset: Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: loc.navHome,
                    index: 0,
                    current: _currentIndex,
                    onTap: _selectIndex),
                _NavItem(
                    icon: Icons.upload_file_outlined,
                    activeIcon: Icons.upload_file,
                    label: loc.navUpload,
                    index: 1,
                    current: _currentIndex,
                    onTap: _selectIndex),
                _NavItem(
                    icon: Icons.image_outlined,
                    activeIcon: Icons.image,
                    label: loc.navXrays,
                    index: 2,
                    current: _currentIndex,
                    onTap: _selectIndex),
                _NavItem(
                    icon: Icons.forum_outlined,
                    activeIcon: Icons.forum,
                    label: loc.navChat,
                    index: 3,
                    current: _currentIndex,
                    onTap: _selectIndex),
                _NavItem(
                    icon: Icons.smart_toy_outlined,
                    activeIcon: Icons.smart_toy,
                    label: loc.navAI,
                    index: 4,
                    current: _currentIndex,
                    onTap: _selectIndex),
                _NavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: loc.navProfile,
                    index: 5,
                    current: _currentIndex,
                    onTap: _selectIndex),
                if (isAdmin)
                  _NavItem(
                      icon: Icons.admin_panel_settings_outlined,
                      activeIcon: Icons.admin_panel_settings,
                      label: loc.navAdmin,
                      index: 6,
                      current: _currentIndex,
                      onTap: _selectIndex),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Non-dismissible OTP Connection Modal (patient-side only)
// ──────────────────────────────────────────────────────────────────

class _PatientOtpConnectionModal extends StatefulWidget {
  final PendingConnection pending;
  final ChatService chatService;

  const _PatientOtpConnectionModal({
    required this.pending,
    required this.chatService,
  });

  @override
  State<_PatientOtpConnectionModal> createState() =>
      _PatientOtpConnectionModalState();
}

class _PatientOtpConnectionModalState
    extends State<_PatientOtpConnectionModal> {
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  Timer? _expiryTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = widget.pending.expiresAt.difference(DateTime.now());
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final remaining = widget.pending.expiresAt.difference(now);
    if (remaining.isNegative) {
      _expiryTimer?.cancel();
      Navigator.of(context).pop(false); // dismiss — OTP expired
    } else {
      setState(() => _remaining = remaining);
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  String get _countdownText {
    final mins = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _verify() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from WhatsApp');
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.chatService.verifyPendingConnection(
        token: token,
        otp: code,
        doctorId: widget.pending.doctorId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true); // success → parent navigates to chat
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Verification failed. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txtSec = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBg : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medical_services_outlined,
                      size: 32, color: AppTheme.primary),
                ),
                const SizedBox(height: 20),

                Text(
                  'Doctor Connection Request',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Dr. ${widget.pending.doctorName} has sent you a connection request. '
                  'Enter the 6-digit code you received on WhatsApp to confirm.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: txtSec,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),

                // Countdown timer
                Text(
                  'Code expires in $_countdownText',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: _remaining.inMinutes < 2
                        ? AppTheme.error
                        : AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),

                // OTP input — always LTR for numbers
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '------',
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 28,
                        letterSpacing: 6,
                        color: txtSec.withValues(alpha: 0.3),
                      ),
                      errorText: _error,
                    ),
                    onChanged: (v) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _verify(),
                  ),
                ),
                const SizedBox(height: 24),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _verify,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _loading ? 'Verifying...' : 'Confirm & Connect',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Dismiss info (user can't dismiss but we explain it)
                Text(
                  'This dialog will close automatically when the code expires.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontSize: 11, color: txtSec),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Nav bar item
// ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isActive
            ? BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon,
                size: 22,
                color: isActive ? AppTheme.primary : AppTheme.textSecondary),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color:
                        isActive ? AppTheme.primary : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
