import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../models/managed_user.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/admin_service.dart';
import '../../../services/api_client.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/alert_utils.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = AdminService();
  List<ManagedUser> _pendingDoctors = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPendingDoctors());
  }

  Future<void> _loadPendingDoctors() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _service.fetchPendingDoctors(token);
      if (!mounted) return;
      setState(() {
        _pendingDoctors = list;
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
        _error = 'Unable to load pending doctors.';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveDoctor(ManagedUser doc) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      await _service.approveDoctor(token: token, id: doc.id);
      _showSnack('Dr. ${doc.name} approved successfully.');
      _loadPendingDoctors();
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Could not approve doctor.', isError: true);
    }
  }

  Future<void> _rejectDoctor(ManagedUser doc) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      await _service.rejectDoctor(token: token, id: doc.id);
      _showSnack('Dr. ${doc.name} registration rejected.');
      _loadPendingDoctors();
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Could not reject doctor.', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AlertUtils.showError(context, msg);
    } else {
      AlertUtils.showSuccess(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txtSec = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Admin Dashboard',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.of(context).pushReplacementNamed('/auth');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending Doctor Approvals',
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: theme.textTheme.headlineMedium?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verify credentials before granting access to diagnosis systems.',
                style: GoogleFonts.dmSans(fontSize: 13, color: txtSec),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.dmSans(
                      color: AppTheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _pendingDoctors.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.verified_outlined,
                                  size: 64,
                                  color: AppTheme.success,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Pending Approvals',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'All registered doctors are verified.',
                                  style: GoogleFonts.dmSans(color: txtSec),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _pendingDoctors.length,
                            itemBuilder: (context, index) {
                              final doc = _pendingDoctors[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isDark
                                        ? AppTheme.darkBorderColor
                                        : AppTheme.borderColor,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: AppTheme.primary
                                                .withValues(alpha: 0.14),
                                            child: Text(
                                              doc.initials,
                                              style: GoogleFonts.dmSans(
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  doc.name,
                                                  style: GoogleFonts.dmSans(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Text(
                                                  doc.email,
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 12,
                                                    color: txtSec,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _infoRow(context, 'Specialization',
                                          doc.specialization ?? 'N/A'),
                                      _infoRow(
                                          context,
                                          'Medical Certificate Details',
                                          doc.medicalCertificate ?? 'N/A'),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => _rejectDoctor(doc),
                                            icon: const Icon(
                                                Icons.cancel_outlined,
                                                color: AppTheme.error),
                                            label: Text(
                                              'Reject',
                                              style: GoogleFonts.dmSans(
                                                  color: AppTheme.error),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _approveDoctor(doc),
                                            icon: const Icon(
                                                Icons.verified_outlined),
                                            label: Text(
                                              'Approve',
                                              style: GoogleFonts.dmSans(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.success,
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final txtSec = theme.brightness == Brightness.dark
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
                fontSize: 11, color: txtSec, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.dmSans(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
