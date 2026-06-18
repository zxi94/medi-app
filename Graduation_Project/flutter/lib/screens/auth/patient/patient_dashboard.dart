import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_client.dart';
import '../../../services/xray_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/shared_widgets.dart';
import '../../../services/chat_service.dart';
import 'package:mediscan_ai/l10n/app_localizations.dart';
import 'report_modal.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final _service = XrayService();
  int _xrayCount = 0;
  XrayRecord? _latestXray;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final stats = await _service.fetchMyStats(token);
      if (!mounted) return;
      setState(() {
        _xrayCount = (stats['xrayCount'] as num?)?.toInt() ?? 0;
        final latest = stats['latestXray'];
        if (latest is Map<String, dynamic>) {
          _latestXray = XrayRecord.fromJson(latest);
        } else {
          _latestXray = null;
        }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;
    final loc = AppLocalizations.of(context)!;
    final firstName = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim().split(RegExp(r'\s+')).first
        : loc.profilePatient;

    final diagnosis = _latestXray?.diagnosisLabel ?? loc.noScansYet;
    final confidence = _latestXray?.confidenceLabel ?? '';
    final dateStr = _latestXray?.uploadDate != null
        ? DateFormat.yMMMd().format(_latestXray!.uploadDate!.toLocal())
        : null;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: const SessionAppTopBar(onProfileTap: null, hideProfileMenu: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.25)),
                  ),
                  child: Text(_error!,
                      style: GoogleFonts.dmSans(
                          color: AppTheme.error, fontWeight: FontWeight.w600)),
                ),
              // Welcome card
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primary, Color(0xFF00838F)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${loc.welcomeBack}, $firstName!',
                              style: GoogleFonts.dmSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              )),
                          const SizedBox(height: 6),
                          Text(loc.latestHealthSummary,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85),
                              )),
                          if (dateStr != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 14, color: Colors.white70),
                                const SizedBox(width: 6),
                                Text('${loc.lastUpload}: $dateStr',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    )),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.health_and_safety_outlined,
                          size: 28, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Summary stats
              if (_isLoading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()))
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 500) {
                      return Row(
                        children: [
                          Expanded(
                              child: StatCard(
                                  title: loc.xraysLabel,
                                  value: '$_xrayCount',
                                  icon: Icons.image_outlined)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: StatCard(
                                  title: loc.statusLabel,
                                  value: _latestXray != null
                                      ? (confidence.isNotEmpty
                                          ? loc.analyzed
                                          : loc.pending)
                                      : loc.noScansYet,
                                  icon: _latestXray != null
                                      ? Icons.check_circle_outline
                                      : Icons.hourglass_empty_outlined,
                                  iconColor: _latestXray != null
                                      ? AppTheme.success
                                      : AppTheme.warning)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: StatCard(
                                  title: loc.confidenceLabel,
                                  value:
                                      confidence.isNotEmpty ? confidence : '--',
                                  icon: Icons.verified_outlined,
                                  iconColor: AppTheme.primary)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: StatCard(
                                    title: loc.xraysLabel,
                                    value: '$_xrayCount',
                                    icon: Icons.image_outlined)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: StatCard(
                                    title: loc.statusLabel,
                                    value: _latestXray != null
                                        ? (confidence.isNotEmpty
                                            ? loc.analyzed
                                            : loc.pending)
                                        : loc.noScansYet,
                                    icon: _latestXray != null
                                        ? Icons.check_circle_outline
                                        : Icons.hourglass_empty_outlined,
                                    iconColor: _latestXray != null
                                        ? AppTheme.success
                                        : AppTheme.warning)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StatCard(
                            title: loc.confidenceLabel,
                            value: confidence.isNotEmpty ? confidence : '--',
                            icon: Icons.verified_outlined,
                            iconColor: AppTheme.primary),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Latest AI Findings
                if (_latestXray != null)
                  SectionCard(
                    title: loc.latestAIFindings,
                    description: loc.yourRecentXray,
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A2E),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.image,
                                  size: 36, color: Colors.white30),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text('Chest X-ray',
                                          style: GoogleFonts.dmSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700)),
                                      DiagnosisBadge(
                                          label: diagnosis,
                                          type: diagnosisToType(diagnosis)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Analyzed on $dateStr',
                                      style: GoogleFonts.dmSans(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppTheme.darkTextSecondary
                                              : AppTheme.textSecondary)),
                                  if (confidence.isNotEmpty)
                                    const SizedBox(height: 8),
                                  if (confidence.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppTheme.darkBackground
                                            : AppTheme.background,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.info_outline,
                                              size: 16,
                                              color: AppTheme.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              loc.language == 'Arabic'
                                                  ? 'اكتشف الذكاء الاصطناعي $diagnosis بثقة $confidence'
                                                  : 'AI detected $diagnosis with $confidence confidence',
                                              style: GoogleFonts.dmSans(
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? AppTheme
                                                          .darkTextSecondary
                                                      : AppTheme.textSecondary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_latestXray != null) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) =>
                                      ReportModal(record: _latestXray!),
                                );
                              }
                            },
                            icon: const Icon(Icons.description_outlined,
                                size: 16),
                            label: Text('View Full Report',
                                style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                // Connect to Doctor
                SectionCard(
                  title: loc.connectToDoctor,
                  description: loc.enterDoctorOtpDesc,
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _showManualOtpModal(context),
                      icon: const Icon(Icons.link, size: 16),
                      label: Text(loc.enterCode,
                          style:
                              GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Health Recommendations
                SectionCard(
                  title: loc.healthRecommendations,
                  description: loc.tipsForRecovery,
                  child: Column(
                    children: [
                      _RecommendationCard(
                        icon: Icons.bedtime_outlined,
                        color: const Color(0xFF7B61FF),
                        title: loc.restRecovery,
                        description: loc.restRecoveryDesc,
                      ),
                      const SizedBox(height: 12),
                      _RecommendationCard(
                        icon: Icons.water_drop_outlined,
                        color: AppTheme.primary,
                        title: loc.stayHydrated,
                        description: loc.stayHydratedDesc,
                      ),
                      const SizedBox(height: 12),
                      _RecommendationCard(
                        icon: Icons.local_pharmacy_outlined,
                        color: AppTheme.success,
                        title: loc.followUpCare,
                        description: loc.followUpCareDesc,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualOtpModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _ManualOtpModal(),
    );
  }
}

class _ManualOtpModal extends StatefulWidget {
  const _ManualOtpModal();
  @override
  State<_ManualOtpModal> createState() => _ManualOtpModalState();
}

class _ManualOtpModalState extends State<_ManualOtpModal> {
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final chatService = context.read<ChatService>();
      await chatService.verifyConnection(token: token, code: code);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor connected successfully!')),
      );
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
    final loc = AppLocalizations.of(context)!;
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
                  child:
                      const Icon(Icons.link, size: 32, color: AppTheme.primary),
                ),
                const SizedBox(height: 20),

                Text(
                  loc.connectToDoctor,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  loc.enterDoctorOtpDesc,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: txtSec,
                    height: 1.5,
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

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed:
                            _loading ? null : () => Navigator.pop(context),
                        child: Text(loc.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _verify,
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(loc.connectToDoctor),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _RecommendationCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                Text(description,
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
