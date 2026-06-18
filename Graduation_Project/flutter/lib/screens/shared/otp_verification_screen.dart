import 'package:mediscan_ai/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/alert_utils.dart';

/// A screen that handles OTP verification via WhatsApp.
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => const OtpVerificationScreen(),
///   ),
/// );
/// ```
///
/// Or via named route:
/// ```dart
/// Navigator.pushNamed(context, '/otp');
/// ```
class OtpVerificationScreen extends StatefulWidget {
  /// Optional phone number to pre-fill the field.
  final String? initialPhone;

  /// Called when verification succeeds — the caller can navigate accordingly.
  final VoidCallback? onVerified;

  const OtpVerificationScreen({
    super.key,
    this.initialPhone,
    this.onVerified,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _chatService = ChatService();

  bool _isSending = false;
  bool _isVerifying = false;
  bool _codeSent = false;
  bool _verified = false;

  /// Cooldown timer — prevents re-sending within 60 s.
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  late final AnimationController _shakeCtrl;

  AppLocalizations get loc => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneCtrl.text = widget.initialPhone!;
    }
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _cooldownTimer?.cancel();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AlertUtils.showError(context, message);
    } else {
      AlertUtils.showSuccess(context, message);
    }
  }

  void _startCooldown() {
    _cooldownSeconds = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldownSeconds--);
      if (_cooldownSeconds <= 0) timer.cancel();
    });
  }

  String? _validatePhone(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.isEmpty) return loc.otpEnterPhone;
    if (cleaned.length < 10) return loc.otpPhoneShort;
    return null;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    final phoneError = _validatePhone(_phoneCtrl.text);
    if (phoneError != null) {
      _showSnack(phoneError, isError: true);
      _shakeCtrl.forward(from: 0);
      return;
    }

    final auth = context.read<AuthProvider>();
    if (auth.token == null) {
      _showSnack(loc.otpMustLogin, isError: true);
      return;
    }

    setState(() => _isSending = true);
    try {
      await _chatService.sendOtp(
        token: auth.token!,
        phone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startCooldown();
      _showSnack(loc.otpSentWhatsapp);
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack(loc.otpNetworkError, isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      _showSnack(loc.otpEnterCode, isError: true);
      _shakeCtrl.forward(from: 0);
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await _chatService.verifyOtp(
        phone: _phoneCtrl.text.trim(),
        code: code,
      );
      if (!mounted) return;
      setState(() => _verified = true);
      _showSnack(loc.otpVerifiedSuccess);
      widget.onVerified?.call();
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
      _shakeCtrl.forward(from: 0);
    } catch (_) {
      _showSnack(loc.otpNetworkError, isError: true);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          loc.otpPhoneVerificationTitle,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                children: [
                  // ── Icon ──
                  _AnimatedIcon(verified: _verified, codeSent: _codeSent),
                  const SizedBox(height: 24),

                  // ── Title ──
                  Text(
                    _verified
                        ? loc.otpVerified
                        : _codeSent
                            ? loc.otpEnterTheCode
                            : loc.otpVerifyPhoneNumber,
                    style: GoogleFonts.dmSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: theme.textTheme.headlineLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _verified
                        ? loc.otpVerifiedDesc
                        : _codeSent
                            ? loc.otpSentDesc
                            : loc.otpSendDesc,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Card ──
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(24),
                      border: theme.cardTheme.shape is RoundedRectangleBorder
                          ? Border.fromBorderSide(
                              (theme.cardTheme.shape as RoundedRectangleBorder)
                                  .side,
                            )
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
                    child: _verified
                        ? _buildVerifiedContent(theme)
                        : _codeSent
                            ? _buildCodeContent(theme, isDark)
                            : _buildPhoneContent(theme, isDark),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Phone Input Step ───────────────────────────────────────────────────────

  Widget _buildPhoneContent(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (context, child) {
            final offset = _shakeCtrl.isAnimating
                ? (4 * (0.5 - _shakeCtrl.value).abs() - 1) * 6
                : 0.0;
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-()]')),
            ],
            decoration: InputDecoration(
              hintText: '01012345678',
              prefixIcon: const Icon(Icons.phone_outlined),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '🇪🇬',
                  style: GoogleFonts.dmSans(fontSize: 22),
                ),
              ),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          loc.otpEgyptianFormat,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSending ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        loc.otpSendCodeBtn,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ── Code Verification Step ────────────────────────────────────────────────

  Widget _buildCodeContent(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show which phone
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkRowBg : AppTheme.statBlueBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.phone_outlined,
                size: 18,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _phoneCtrl.text.trim(),
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _codeSent = false;
                  _codeCtrl.clear();
                  _cooldownTimer?.cancel();
                  _cooldownSeconds = 0;
                }),
                child: Text(
                  loc.otpChangeBtn,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          loc.otpVerificationCode,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (context, child) {
            final offset = _shakeCtrl.isAnimating
                ? (4 * (0.5 - _shakeCtrl.value).abs() - 1) * 6
                : 0.0;
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.dmSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 12,
              color: theme.textTheme.bodyLarge?.color,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '• • • • • •',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Verify button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isVerifying ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isVerifying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        loc.otpVerifyBtn,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Resend button with cooldown
        Center(
          child: _cooldownSeconds > 0
              ? Text(
                  loc.otpResendIn +
                      _cooldownSeconds.toString() +
                      loc.otpSeconds,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                )
              : TextButton.icon(
                  onPressed: _isSending ? null : _sendOtp,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    loc.otpResendCodeBtn,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Success State ──────────────────────────────────────────────────────────

  Widget _buildVerifiedContent(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          loc.otpProceedDesc,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.maybePop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 18),
                const SizedBox(width: 8),
                Text(
                  loc.otpDoneBtn,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Animated Icon Widget ─────────────────────────────────────────────────────

class _AnimatedIcon extends StatelessWidget {
  final bool verified;
  final bool codeSent;

  const _AnimatedIcon({required this.verified, required this.codeSent});

  @override
  Widget build(BuildContext context) {
    final icon = verified
        ? Icons.verified_rounded
        : codeSent
            ? Icons.sms_outlined
            : Icons.phone_android_outlined;

    final color = verified ? AppTheme.success : AppTheme.primary;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 38),
      ),
    );
  }
}
