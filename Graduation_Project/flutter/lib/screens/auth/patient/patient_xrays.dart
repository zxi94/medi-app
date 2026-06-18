import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/api_client.dart';
import '../../../services/xray_service.dart';
import '../../../theme/app_theme.dart';
import 'report_modal.dart';
import '../../../widgets/shared_widgets.dart';

class PatientXraysScreen extends StatefulWidget {
  const PatientXraysScreen({super.key});

  @override
  State<PatientXraysScreen> createState() => _PatientXraysScreenState();
}

class _PatientXraysScreenState extends State<PatientXraysScreen> {
  final _service = XrayService();
  List<XrayRecord> _xrays = [];
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
      final xrays = await _service.fetchMyXrays(token);
      if (!mounted) return;
      setState(() {
        _xrays = xrays;
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
        _error = 'Unable to load X-rays.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: const SessionAppTopBar(hideProfileMenu: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My X-rays',
                  style: GoogleFonts.dmSans(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Your X-ray history and AI analysis results',
                  style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary)),
              const SizedBox(height: 20),
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
              if (_isLoading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator()))
              else
                SectionCard(
                  title: 'X-ray History',
                  description:
                      '${_xrays.length} scan${_xrays.length == 1 ? '' : 's'} total',
                  child: _xrays.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              'No X-rays yet. Upload your first X-ray to get started.',
                              style: GoogleFonts.dmSans(
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary)),
                        )
                      : Column(
                          children: _xrays.asMap().entries.map((entry) {
                            final i = entry.key;
                            final xray = entry.value;
                            return Column(
                              children: [
                                if (i > 0) const Divider(height: 20),
                                _XrayRow(xray: xray),
                              ],
                            );
                          }).toList(),
                        ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _XrayRow extends StatelessWidget {
  final XrayRecord xray;
  const _XrayRow({required this.xray});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diagnosis = xray.diagnosisLabel;
    final confidence = xray.confidenceLabel;
    final date = xray.uploadDate != null
        ? DateFormat.yMMMd().format(xray.uploadDate!.toLocal())
        : 'Unknown';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.image, size: 28, color: Colors.white30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text('Chest X-ray',
                      style: GoogleFonts.dmSans(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  DiagnosisBadge(
                    label: diagnosis,
                    type: diagnosisToType(diagnosis),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(date,
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary)),
              if (confidence.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.verified_outlined,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text('AI Confidence: $confidence',
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: AppTheme.primary)),
                  ],
                ),
              ],
            ],
          ),
        ),
        TextButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => ReportModal(record: xray),
            );
          },
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
          child: Text('View',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.primary)),
        ),
      ],
    );
  }
}
