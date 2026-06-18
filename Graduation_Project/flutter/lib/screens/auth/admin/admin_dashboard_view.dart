import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../models/managed_user.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/admin_service.dart';
import '../../../services/api_client.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/alert_utils.dart';
import '../doctor/doctor_main.dart';
import '../patient/patient_main.dart';

class MainUserNavigationView extends StatelessWidget {
  const MainUserNavigationView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    if (auth.role?.toUpperCase() == 'DOCTOR') {
      return const DoctorMainScreen();
    } else {
      return const PatientMainScreen();
    }
  }
}

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView>
    with SingleTickerProviderStateMixin {
  final _service = AdminService();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<ManagedUser> _pendingDoctors = [];
  List<ManagedUser> _allUsers = [];
  bool _isLoadingPending = true;
  bool _isLoadingAll = true;
  String? _errorPending;
  String? _errorAll;
  final Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadPendingDoctors();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.index == 1 && _allUsers.isEmpty) {
      _loadAllUsers();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_tabController.index == 0) {
        _loadPendingDoctors();
      } else {
        _loadAllUsers();
      }
    });
  }

  Future<void> _loadPendingDoctors() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _isLoadingPending = true;
      _errorPending = null;
    });

    try {
      final query = _searchController.text;
      final list = await _service.fetchPendingDoctors(token, search: query);
      if (!mounted) return;
      setState(() {
        _pendingDoctors = list;
        _isLoadingPending = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorPending = e.message;
        _isLoadingPending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorPending = 'Unable to load pending approvals.';
        _isLoadingPending = false;
      });
    }
  }

  Future<void> _loadAllUsers() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _isLoadingAll = true;
      _errorAll = null;
    });

    try {
      final query = _searchController.text;
      final list = await _service.fetchAllUsers(token, search: query);
      if (!mounted) return;
      setState(() {
        _allUsers = list;
        _isLoadingAll = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAll = e.message;
        _isLoadingAll = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorAll = 'Unable to load active users.';
        _isLoadingAll = false;
      });
    }
  }

  Future<void> _approveDoctor(ManagedUser doc) async {
    if (_processingIds.contains(doc.id)) return;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _processingIds.add(doc.id));
    try {
      await _service.approveDoctor(token: token, id: doc.id);
      _showSnack('Dr. ${doc.name} approved successfully.');

      // Smoothly remove approved doctor from the list with setState
      setState(() {
        _pendingDoctors.removeWhere((item) => item.id == doc.id);
        _processingIds.remove(doc.id);
      });
      // Optionally reload both lists silently in background
      _loadAllUsers();
    } on ApiException catch (e) {
      setState(() => _processingIds.remove(doc.id));
      _showSnack(e.message, isError: true);
    } catch (_) {
      setState(() => _processingIds.remove(doc.id));
      _showSnack('Could not approve doctor.', isError: true);
    }
  }

  Future<void> _rejectDoctor(ManagedUser doc) async {
    if (_processingIds.contains(doc.id)) return;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _processingIds.add(doc.id));
    try {
      await _service.rejectDoctor(token: token, id: doc.id);
      _showSnack('Dr. ${doc.name} rejected.');

      setState(() {
        _pendingDoctors.removeWhere((item) => item.id == doc.id);
        _processingIds.remove(doc.id);
      });
      _loadAllUsers();
    } on ApiException catch (e) {
      setState(() => _processingIds.remove(doc.id));
      _showSnack(e.message, isError: true);
    } catch (_) {
      setState(() => _processingIds.remove(doc.id));
      _showSnack('Could not reject doctor.', isError: true);
    }
  }

  Future<void> _suspendUser(ManagedUser user) async {
    if (_processingIds.contains(user.id)) return;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _processingIds.add(user.id));
    try {
      await _service.suspendUser(token: token, id: user.id);
      _showSnack('${user.name} has been suspended.');

      setState(() {
        _processingIds.remove(user.id);
      });
      _loadAllUsers(); // Reload to update status icon and details
    } on ApiException catch (e) {
      setState(() => _processingIds.remove(user.id));
      _showSnack(e.message, isError: true);
    } catch (_) {
      setState(() => _processingIds.remove(user.id));
      _showSnack('Could not suspend user.', isError: true);
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
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Control Center',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.of(context).pushReplacementNamed('/auth');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Application Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E3C72), const Color(0xFF2A5298)]
                        : [
                            AppTheme.primary,
                            AppTheme.primary.withValues(alpha: 0.8)
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'MediScan AI Control Center',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'System Status: Active & Secured',
                          style: GoogleFonts.dmSans(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle: GoogleFonts.dmSans(color: txtSec),
                  prefixIcon: const Icon(Icons.search_outlined),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.dmSans(),
              ),
              const SizedBox(height: 16),
              // Custom Sliding Segmented Tab Controller
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2E2E2E)
                        : const Color(0xFFE2E2E2),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: txtSec,
                  labelStyle: GoogleFonts.dmSans(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Pending Doctors'),
                    Tab(text: 'Active System Users'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // TabBar Views containing scrollable lists
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingDoctorsList(isDark, txtSec),
                    _buildAllUsersList(isDark, txtSec),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingDoctorsList(bool isDark, Color txtSec) {
    if (_isLoadingPending) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorPending != null) {
      return Center(
        child: Text(_errorPending!,
            style: GoogleFonts.dmSans(
                color: AppTheme.error, fontWeight: FontWeight.bold)),
      );
    }
    if (_pendingDoctors.isEmpty) {
      return _buildEmptyState(
        icon: Icons.verified_user_outlined,
        title: 'All Caught Up!',
        subtitle: 'No doctor applications are pending approval.',
        txtSec: txtSec,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPendingDoctors,
      child: ListView.builder(
        itemCount: _pendingDoctors.length,
        itemBuilder: (context, index) {
          final doc = _pendingDoctors[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color:
                    isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E2E2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.12),
                        child: Text(
                          doc.initials,
                          style: GoogleFonts.dmSans(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.name,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              doc.email,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: txtSec,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoField('Specialization',
                      doc.specialization ?? 'Radiology', txtSec),
                  _infoField(
                      'Medical Certificate Details',
                      doc.medicalCertificate ?? 'Verification Details pending',
                      txtSec),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _processingIds.contains(doc.id)
                            ? null
                            : () => _rejectDoctor(doc),
                        icon: _processingIds.contains(doc.id)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.close_outlined, size: 16),
                        label: Text(
                          'Reject',
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _processingIds.contains(doc.id)
                            ? null
                            : () => _approveDoctor(doc),
                        icon: _processingIds.contains(doc.id)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_outline_outlined,
                                size: 16),
                        label: Text(
                          'Approve',
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
    );
  }

  Widget _buildAllUsersList(bool isDark, Color txtSec) {
    if (_isLoadingAll) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorAll != null) {
      return Center(
        child: Text(_errorAll!,
            style: GoogleFonts.dmSans(
                color: AppTheme.error, fontWeight: FontWeight.bold)),
      );
    }
    if (_allUsers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No Registered Users',
        subtitle: 'The system has no active users registered.',
        txtSec: txtSec,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAllUsers,
      child: ListView.builder(
        itemCount: _allUsers.length,
        itemBuilder: (context, index) {
          final u = _allUsers[index];
          final roleColor = switch (u.role.toUpperCase()) {
            'DOCTOR' => AppTheme.primary,
            'ADMIN' => const Color(0xFFFF9800),
            _ => const Color(0xFF4CAF50),
          };

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color:
                    isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E2E2),
              ),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: roleColor.withValues(alpha: 0.12),
                child: Text(
                  u.initials,
                  style: GoogleFonts.dmSans(
                    color: roleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      u.name.isEmpty ? 'System User' : u.name,
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      u.role.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        color: roleColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  u.email,
                  style: GoogleFonts.dmSans(fontSize: 11, color: txtSec),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    u.verificationStatus?.toLowerCase() == 'approved'
                        ? Icons.check_circle_outlined
                        : u.verificationStatus?.toLowerCase() == 'suspended'
                            ? Icons.block_outlined
                            : Icons.pending_outlined,
                    color: u.verificationStatus?.toLowerCase() == 'approved'
                        ? const Color(0xFF4CAF50)
                        : u.verificationStatus?.toLowerCase() == 'suspended'
                            ? AppTheme.error
                            : const Color(0xFFFF9800),
                    size: 20,
                  ),
                  if (u.role.toUpperCase() != 'ADMIN' &&
                      u.verificationStatus?.toLowerCase() != 'suspended') ...[
                    const SizedBox(width: 12),
                    IconButton(
                      icon: _processingIds.contains(u.id)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.do_not_disturb_alt_outlined,
                              size: 20),
                      color: AppTheme.error,
                      tooltip: 'Suspend User',
                      onPressed: _processingIds.contains(u.id)
                          ? null
                          : () => _suspendUser(u),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color txtSec,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 48, color: AppTheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 12, color: txtSec),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoField(String label, String value, Color txtSec) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
                fontSize: 9,
                color: txtSec,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style:
                GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
