import '../models/managed_user.dart';
import 'api_client.dart';

class AdminActivity {
  final Map<String, dynamic> stats;
  final List<ManagedUser> recentUsers;
  final List<Map<String, dynamic>> recentMessages;

  const AdminActivity({
    required this.stats,
    required this.recentUsers,
    required this.recentMessages,
  });
}

class AdminService {
  final ApiClient _api;

  AdminService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<ManagedUser>> fetchUsers({
    required String token,
    String? role,
    String? search,
  }) async {
    final params = <String>[];
    if (role != null && role.isNotEmpty && role != 'all') {
      params.add('role=$role');
    }
    if (search != null && search.trim().isNotEmpty) {
      params.add('search=${Uri.encodeQueryComponent(search.trim())}');
    }
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final body = await _api.get('/api/admin/users$query', token: token);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final users = data['users'] as List? ?? const [];
    return users
        .whereType<Map<String, dynamic>>()
        .map(ManagedUser.fromJson)
        .toList();
  }

  Future<ManagedUser> createUser({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final body =
        await _api.post('/api/admin/users', token: token, body: payload);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return ManagedUser.fromJson(data['user'] as Map<String, dynamic>? ?? {});
  }

  Future<ManagedUser> updateUser({
    required String token,
    required int id,
    required Map<String, dynamic> payload,
  }) async {
    final body = await _api.patch(
      '/api/admin/users/$id',
      token: token,
      body: payload,
    );
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return ManagedUser.fromJson(data['user'] as Map<String, dynamic>? ?? {});
  }

  Future<void> deleteUser({
    required String token,
    required int id,
  }) async {
    await _api.delete('/api/admin/users/$id', token: token);
  }

  Future<AdminActivity> fetchActivity(String token) async {
    final body = await _api.get('/api/admin/activity', token: token);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final recentUsers = data['recent_users'] as List? ?? const [];
    final recentMessages = data['recent_messages'] as List? ?? const [];
    return AdminActivity(
      stats: data['stats'] as Map<String, dynamic>? ?? const {},
      recentUsers: recentUsers
          .whereType<Map<String, dynamic>>()
          .map(ManagedUser.fromJson)
          .toList(),
      recentMessages: recentMessages.whereType<Map<String, dynamic>>().toList(),
    );
  }

  Future<List<ManagedUser>> fetchPendingDoctors(String token,
      {String? search}) async {
    final query = search != null && search.trim().isNotEmpty
        ? '?status=PENDING&q=${Uri.encodeQueryComponent(search.trim())}'
        : '?status=PENDING';
    final body = await _api.get('/api/admin/doctors$query', token: token);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final users = data['users'] as List? ?? const [];
    return users
        .whereType<Map<String, dynamic>>()
        .map(ManagedUser.fromJson)
        .toList();
  }

  Future<List<ManagedUser>> fetchAllUsers(String token,
      {String? search}) async {
    final query = search != null && search.trim().isNotEmpty
        ? '?q=${Uri.encodeQueryComponent(search.trim())}'
        : '';
    final body = await _api.get('/api/admin/doctors$query', token: token);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final users = data['users'] as List? ?? const [];
    return users
        .whereType<Map<String, dynamic>>()
        .map(ManagedUser.fromJson)
        .toList();
  }

  Future<void> approveDoctor({
    required String token,
    required int id,
  }) async {
    await _api.put('/api/admin/doctors/$id/approve', token: token);
  }

  Future<void> rejectDoctor({
    required String token,
    required int id,
  }) async {
    await _api.put('/api/admin/doctors/$id/reject', token: token);
  }

  Future<void> suspendUser({
    required String token,
    required int id,
  }) async {
    await _api.put('/api/admin/users/$id/suspend', token: token);
  }
}
