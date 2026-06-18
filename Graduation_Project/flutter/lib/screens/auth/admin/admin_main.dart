import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/managed_user.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/admin_service.dart';
import '../../../services/api_client.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/alert_utils.dart';
import '../../../widgets/shared_widgets.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  final _service = AdminService();
  final _searchCtrl = TextEditingController();

  List<ManagedUser> _users = [];
  AdminActivity? _activity;
  String _roleFilter = 'all';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.fetchUsers(
          token: token,
          role: _roleFilter,
          search: _searchCtrl.text,
        ),
        _service.fetchActivity(token),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<ManagedUser>;
        _activity = results[1] as AdminActivity;
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
        _error = 'Unable to load admin data.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openUserSheet([ManagedUser? user]) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _UserFormSheet(user: user),
    );
    if (payload == null) return;

    try {
      if (user == null) {
        await _service.createUser(token: token, payload: payload);
      } else {
        await _service.updateUser(token: token, id: user.id, payload: payload);
      }
      await _load();
      _showSnack(user == null ? 'User created.' : 'User updated.');
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Could not save user.', isError: true);
    }
  }

  Future<void> _deleteUser(ManagedUser user) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final confirmed = await AlertUtils.showConfirmationDialog(
      context,
      title: 'Delete user',
      content: 'Delete ${user.name.isEmpty ? user.email : user.name}?',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true) return;

    try {
      await _service.deleteUser(token: token, id: user.id);
      await _load();
      _showSnack('User deleted.');
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Could not delete user.', isError: true);
    }
  }

  Future<void> _setDoctorVerification(ManagedUser user, String status) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      await _service.updateUser(
        token: token,
        id: user.id,
        payload: {'verification_status': status},
      );
      await _load();
      _showSnack('Doctor ${status == 'approved' ? 'approved' : 'rejected'}.');
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Could not update doctor verification.', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AlertUtils.showError(context, message);
    } else {
      AlertUtils.showSuccess(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txtSec = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    if (!auth.isAdmin) {
      return Scaffold(
        appBar: const SessionAppTopBar(hideProfileMenu: true),
        body: Center(
          child: Text(
            'Admin access required',
            style:
                GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const SessionAppTopBar(hideProfileMenu: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Management',
                              style: GoogleFonts.dmSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: theme.textTheme.headlineLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage patients, doctors, administrators, and activity',
                              style: GoogleFonts.dmSans(
                                  fontSize: 14, color: txtSec),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => _openUserSheet(),
                          icon: const Icon(Icons.person_add_alt_1, size: 22),
                          label: Text(
                            'Add User',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ErrorBanner(
                        message: _error!,
                        onDismiss: () => setState(() => _error = null),
                      ),
                    ),
                  _StatsGrid(activity: _activity),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth > 900;
                        final users = _UsersPanel(
                          users: _users,
                          roleFilter: _roleFilter,
                          searchCtrl: _searchCtrl,
                          onRoleChanged: (value) {
                            setState(() => _roleFilter = value);
                            _load();
                          },
                          onSearch: _load,
                          onEdit: _openUserSheet,
                          onDelete: _deleteUser,
                          onVerify: _setDoctorVerification,
                        );
                        final activity = _ActivityPanel(activity: _activity);
                        if (!wide) {
                          return Column(
                            children: [
                              users,
                              const SizedBox(height: 16),
                              activity,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: users),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: activity),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final AdminActivity? activity;

  const _StatsGrid({required this.activity});

  @override
  Widget build(BuildContext context) {
    final stats = activity?.stats ?? const {};
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth > 760 ? 4 : 2;
        return GridView.count(
          crossAxisCount: count,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 760 ? 2.5 : 1.7,
          children: [
            StatCard(
              title: 'Total Users',
              value: '${stats['totalUsers'] ?? 0}',
              icon: Icons.groups_outlined,
            ),
            StatCard(
              title: 'Patients',
              value: '${stats['patients'] ?? 0}',
              icon: Icons.personal_injury_outlined,
              iconColor: AppTheme.success,
            ),
            StatCard(
              title: 'Doctors',
              value: '${stats['doctors'] ?? 0}',
              icon: Icons.medical_services_outlined,
              iconColor: AppTheme.primary,
            ),
            StatCard(
              title: 'Pending Doctors',
              value: '${stats['pendingDoctors'] ?? 0}',
              icon: Icons.pending_actions_outlined,
              iconColor: AppTheme.warning,
            ),
          ],
        );
      },
    );
  }
}

class _UsersPanel extends StatelessWidget {
  final List<ManagedUser> users;
  final String roleFilter;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onSearch;
  final ValueChanged<ManagedUser> onEdit;
  final ValueChanged<ManagedUser> onDelete;
  final void Function(ManagedUser user, String status) onVerify;

  const _UsersPanel({
    required this.users,
    required this.roleFilter,
    required this.searchCtrl,
    required this.onRoleChanged,
    required this.onSearch,
    required this.onEdit,
    required this.onDelete,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SectionCard(
      title: 'Users',
      description: 'Patients, doctors, and administrators',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onSubmitted: (_) => onSearch(),
                  decoration: const InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: roleFilter,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'patient', child: Text('Patients')),
                  DropdownMenuItem(value: 'doctor', child: Text('Doctors')),
                  DropdownMenuItem(value: 'admin', child: Text('Admins')),
                ],
                onChanged: (value) {
                  if (value != null) onRoleChanged(value);
                },
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: onSearch,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (users.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No users found',
                style: GoogleFonts.dmSans(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
            )
          else
            ...users.map(
              (user) => Column(
                children: [
                  _UserRow(
                    user: user,
                    onEdit: () => onEdit(user),
                    onDelete: () => onDelete(user),
                    onVerify: (status) => onVerify(user, status),
                  ),
                  Divider(height: 1, color: theme.dividerTheme.color),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final ManagedUser user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onVerify;

  const _UserRow({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txtSec = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final roleColor = switch (user.role) {
      'doctor' => AppTheme.primary,
      'admin' => AppTheme.warning,
      _ => AppTheme.success,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: roleColor.withValues(alpha: 0.14),
            child: Text(
              user.initials,
              style: GoogleFonts.dmSans(
                color: roleColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isEmpty ? user.email : user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontSize: 12, color: txtSec),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DiagnosisBadge(label: user.role, type: BadgeType.info),
          if (user.role == 'doctor') ...[
            const SizedBox(width: 8),
            DiagnosisBadge(
              label: user.verificationStatus ?? 'pending',
              type: diagnosisToType(user.verificationStatus ?? 'pending'),
            ),
            if (user.verificationStatus != 'approved') ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Approve doctor',
                icon: const Icon(Icons.verified_outlined,
                    color: AppTheme.success),
                onPressed: () => onVerify('approved'),
              ),
            ],
            if (user.verificationStatus != 'rejected') ...[
              IconButton(
                tooltip: 'Reject doctor',
                icon: const Icon(Icons.cancel_outlined, color: AppTheme.error),
                onPressed: () => onVerify('rejected'),
              ),
            ],
          ],
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  final AdminActivity? activity;

  const _ActivityPanel({required this.activity});

  @override
  Widget build(BuildContext context) {
    final recentUsers = activity?.recentUsers ?? const [];
    final recentMessages = activity?.recentMessages ?? const [];
    final theme = Theme.of(context);
    final txtSec = theme.brightness == Brightness.dark
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;

    return SectionCard(
      title: 'Activity',
      description: 'Recent account and chat activity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New accounts',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (recentUsers.isEmpty)
            Text('No recent accounts', style: GoogleFonts.dmSans(color: txtSec))
          else
            ...recentUsers.take(5).map(
                  (user) => _ActivityLine(
                    icon: Icons.person_add_alt_1,
                    title: user.name.isEmpty ? user.email : user.name,
                    subtitle: '${user.role} - ${_formatDate(user.createdAt)}',
                  ),
                ),
          const SizedBox(height: 16),
          Text(
            'Latest messages',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (recentMessages.isEmpty)
            Text('No chat messages yet',
                style: GoogleFonts.dmSans(color: txtSec))
          else
            ...recentMessages.take(5).map(
                  (message) => _ActivityLine(
                    icon: Icons.chat_bubble_outline,
                    title:
                        message['sender_email'] as String? ?? 'Unknown sender',
                    subtitle: message['body'] as String? ?? '',
                  ),
                ),
        ],
      ),
    );
  }
}

class _ActivityLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ActivityLine({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txtSec = theme.brightness == Brightness.dark
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontSize: 12, color: txtSec),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserFormSheet extends StatefulWidget {
  final ManagedUser? user;

  const _UserFormSheet({this.user});

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  late String _role = widget.user?.role ?? 'patient';
  late String _verification = widget.user?.verificationStatus ?? 'pending';
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.user?.name ?? '');
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.user?.email ?? '');
  final _passwordCtrl = TextEditingController();
  late final TextEditingController _dobCtrl =
      TextEditingController(text: widget.user?.dob ?? '1990-01-01');
  late final TextEditingController _genderCtrl =
      TextEditingController(text: widget.user?.gender ?? 'other');
  late final TextEditingController _specializationCtrl =
      TextEditingController(text: widget.user?.specialization ?? 'Radiology');
  late final TextEditingController _certificateCtrl = TextEditingController(
    text: widget.user?.medicalCertificate ?? 'Pending certificate upload',
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _dobCtrl.dispose();
    _genderCtrl.dispose();
    _specializationCtrl.dispose();
    _certificateCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final isCreate = widget.user == null;
    if (_emailCtrl.text.trim().isEmpty) return;
    if (isCreate && _passwordCtrl.text.length < 8) return;
    if (_role != 'admin' && _nameCtrl.text.trim().isEmpty) return;

    final payload = <String, dynamic>{
      'role': _role,
      if (_nameCtrl.text.trim().isNotEmpty) 'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      if (_passwordCtrl.text.isNotEmpty) 'password': _passwordCtrl.text,
    };
    if (_role == 'patient') {
      payload.addAll({
        'gender':
            _genderCtrl.text.trim().isEmpty ? 'other' : _genderCtrl.text.trim(),
        'dob':
            _dobCtrl.text.trim().isEmpty ? '1990-01-01' : _dobCtrl.text.trim(),
      });
    }
    if (_role == 'doctor') {
      payload.addAll({
        'specialization': _specializationCtrl.text.trim(),
        'medical_certificate': _certificateCtrl.text.trim(),
        'verification_status': _verification,
      });
    }
    Navigator.pop(context, payload);
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.user == null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isCreate ? 'Add User' : 'Edit User',
                      style: GoogleFonts.dmSans(
                          fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'patient', child: Text('Patient')),
                  DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) => setState(() => _role = value ?? _role),
              ),
              const SizedBox(height: 12),
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
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: isCreate ? 'Password' : 'New password',
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              if (_role == 'patient') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _genderCtrl,
                        decoration: const InputDecoration(labelText: 'Gender'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _dobCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Date of birth'),
                      ),
                    ),
                  ],
                ),
              ],
              if (_role == 'doctor') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _specializationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Specialization',
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _certificateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Medical certificate',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _verification,
                  decoration: const InputDecoration(labelText: 'Verification'),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                        value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(
                        value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _verification = value);
                  },
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(isCreate ? 'Create User' : 'Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const _ErrorBanner({required this.message, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, size: 18, color: AppTheme.error),
            ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '';
  return DateFormat.yMMMd().format(date.toLocal());
}
