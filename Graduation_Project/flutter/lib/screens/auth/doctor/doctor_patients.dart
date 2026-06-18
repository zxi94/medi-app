import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../models/chat_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_client.dart';
import '../../../services/chat_service.dart';
import '../../../services/xray_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/alert_utils.dart';
import '../../../widgets/shared_widgets.dart';

class DoctorPatientsScreen extends StatefulWidget {
  final int refreshKey;

  const DoctorPatientsScreen({super.key, this.refreshKey = 0});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen>
    with WidgetsBindingObserver {
  final _service = XrayService();
  final _chatService = ChatService();
  List<Map<String, dynamic>> _patients = [];
  List<ChatContact> _chatContacts = [];
  bool _isLoading = true;
  String? _error;
  String _search = '';
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    // Auto-refresh every 30 seconds to show status chip updates
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void didUpdateWidget(covariant DoctorPatientsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      _load(silent: true);
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final patients = await _service.fetchDoctorPatients(token);
      final chatContacts = await _chatService.fetchContacts(token);
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _chatContacts = chatContacts;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = 'Unable to load patients.';
          _isLoading = false;
        });
      }
    }
  }

  /// Looks up the connection status for a patient from the contacts list.
  String _connectionStatus(Map<String, dynamic> patient) {
    final patientEmail = patient['email'] as String? ?? '';
    for (final c in _chatContacts) {
      if (c.email == patientEmail) {
        return c.verificationStatus ?? 'PENDING_VERIFICATION';
      }
    }
    return 'NOT_CONNECTED';
  }

  List<Map<String, dynamic>> get _filtered => _patients.where((p) {
        if (_search.isEmpty) return true;
        final name = (p['name'] as String? ?? '').toLowerCase();
        final email = (p['email'] as String? ?? '').toLowerCase();
        final q = _search.toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();

  Future<void> _showAddPatientDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AddPatientDialog(chatService: _chatService),
    );
    if (result == true && mounted) {
      AlertUtils.showSuccess(
        context,
        'WhatsApp verification code sent to patient. Connection will appear as "Pending" until they confirm.',
      );
      await _load(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final isPending = auth.user?.verificationStatus == null ||
        auth.user?.verificationStatus == 'pending';

    if (isPending) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: const SessionAppTopBar(hideProfileMenu: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline,
                    size: 48, color: AppTheme.warning),
                const SizedBox(height: 16),
                Text('Account Pending Approval',
                    style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.warning)),
                const SizedBox(height: 8),
                Text(
                    'Your account is awaiting admin verification. You will be able to manage patients once approved.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    final filtered = _filtered;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const SessionAppTopBar(hideProfileMenu: true),
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
              Row(
                children: [
                  Text('Patient Management',
                      style: GoogleFonts.dmSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.headlineMedium?.color,
                      )),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _load,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _showAddPatientDialog,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add Patient via WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator()))
              else
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorderColor
                          : AppTheme.borderColor,
                      width: 1.18,
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('All Patients',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            theme.textTheme.titleLarge?.color,
                                      )),
                                  Text(
                                      '${filtered.length} patient${filtered.length == 1 ? '' : 's'}',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.textSecondary,
                                      )),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 180,
                              child: TextField(
                                onChanged: (v) => setState(() => _search = v),
                                style: GoogleFonts.dmSans(fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Search patients...',
                                  prefixIcon: Icon(Icons.search, size: 18),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        color: isDark
                            ? AppTheme.darkBackground
                            : AppTheme.background,
                        child: const Row(
                          children: [
                            _TableHeader('Name', flex: 2),
                            _TableHeader('Diagnosis', flex: 2),
                            _TableHeader('Date', flex: 2),
                            _TableHeader('Status', flex: 2),
                            _TableHeader('', flex: 1),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Patient rows
                      ...filtered.map((patient) => Column(
                            children: [
                              _PatientRow(
                                patient: patient,
                                connectionStatus: _connectionStatus(patient),
                                onView: () =>
                                    _showPatientDetail(context, patient),
                              ),
                              const Divider(height: 1),
                            ],
                          )),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.people_outline,
                                    size: 40,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.textSecondary),
                                const SizedBox(height: 8),
                                Text('No patients found',
                                    style: GoogleFonts.dmSans(
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPatientDetail(BuildContext context, Map<String, dynamic> patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final sheetTheme = Theme.of(sheetContext);
        final isDark = sheetTheme.brightness == Brightness.dark;
        final diagnosis = patient['latestDiagnosis']?['label'] as String? ??
            patient['latestDiagnosis']?['prediction'] as String? ??
            'Pending';
        final status = patient['status'] as String? ?? 'pending';
        final date = patient['latestDate'] as String? ?? '';
        final formattedDate = date.isNotEmpty ? date.split('T')[0] : '';

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => SingleChildScrollView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Patient Details',
                        style: GoogleFonts.dmSans(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext)),
                  ],
                ),
                Text('Medical record',
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _DetailField(
                        label: 'Name',
                        value: patient['name'] as String? ?? 'Unknown'),
                    const SizedBox(width: 16),
                    _DetailField(
                        label: 'Gender',
                        value: patient['gender'] as String? ?? '--'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _DetailField(
                        label: 'Email',
                        value: patient['email'] as String? ?? '--'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status',
                              style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          DiagnosisBadge(
                              label: status, type: diagnosisToType(status)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (diagnosis != 'Pending')
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkBackground
                          : AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.history,
                              size: 18, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Text('Latest Diagnosis',
                              style: GoogleFonts.dmSans(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 12),
                        _HistoryItem(
                            diagnosis: diagnosis,
                            date: formattedDate,
                            description: 'AI-assisted chest X-ray analysis'),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Connection Status Chip
// ──────────────────────────────────────────────────────────────────

class _ConnectionChip extends StatelessWidget {
  final String status;
  const _ConnectionChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'ACTIVE';
    final isPending = status == 'PENDING_VERIFICATION';
    final color = isActive
        ? const Color(0xFF22C55E) // green
        : isPending
            ? const Color(0xFFF59E0B) // amber
            : AppTheme.textSecondary;
    final label = isActive
        ? 'Connected'
        : isPending
            ? 'Pending'
            : 'Not Connected';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Table widgets
// ──────────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  final String text;
  final int flex;
  const _TableHeader(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      flex: flex,
      child: Text(text,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          )),
    );
  }
}

class _PatientRow extends StatelessWidget {
  final Map<String, dynamic> patient;
  final String connectionStatus;
  final VoidCallback onView;

  const _PatientRow({
    required this.patient,
    required this.connectionStatus,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = patient['name'] as String? ?? 'Unknown';
    final diagnosis = patient['latestDiagnosis']?['label'] as String? ??
        patient['latestDiagnosis']?['prediction'] as String? ??
        'Pending';
    final date = patient['latestDate'] as String? ?? '';
    final formattedDate = date.isNotEmpty ? date.split('T')[0] : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodyLarge?.color))),
          Expanded(
              flex: 2,
              child: Text(diagnosis,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: theme.textTheme.bodyMedium?.color))),
          Expanded(
              flex: 2,
              child: Text(formattedDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary))),
          Expanded(flex: 2, child: _ConnectionChip(status: connectionStatus)),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: onView,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                tooltip: 'View',
                color: AppTheme.primary,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;
  const _DetailField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.titleMedium?.color)),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final String diagnosis;
  final String date;
  final String description;
  const _HistoryItem(
      {required this.diagnosis, required this.date, required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
                color: AppTheme.primary, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(diagnosis,
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.titleSmall?.color)),
                  Text(date,
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary)),
                ],
              ),
              const SizedBox(height: 2),
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
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// _AddPatientDialog — SINGLE STEP (doctor sends code only; no OTP entry)
// ──────────────────────────────────────────────────────────────────

class _AddPatientDialog extends StatefulWidget {
  final ChatService chatService;
  const _AddPatientDialog({required this.chatService});

  @override
  State<_AddPatientDialog> createState() => _AddPatientDialogState();
}

class _AddPatientDialogState extends State<_AddPatientDialog> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final token = context.read<AuthProvider>().token;
    final phone = _phoneCtrl.text.trim();
    if (token == null || phone.isEmpty) return;

    setState(() => _loading = true);
    try {
      // Doctor sends the request. Backend sends WhatsApp OTP to patient.
      // The doctor does NOT enter or see the OTP — the patient will.
      await widget.chatService.sendConnectionRequest(
        token: token,
        phone: phone,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      AlertUtils.showError(context, e.message);
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      AlertUtils.showError(
          context, 'Could not send code. Check phone number and try again.');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Patient via WhatsApp',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the patient\'s phone number. They will receive a WhatsApp verification code to confirm the connection.',
            style:
                GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            textDirection: TextDirection.ltr, // phone numbers always LTR
            decoration: const InputDecoration(
              labelText: 'Patient Phone Number',
              hintText: '+201xxxxxxxxx',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _sendCode,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_loading ? 'Sending...' : 'Send Code via WhatsApp'),
        ),
      ],
    );
  }
}
