import '../models/app_user.dart';
import 'api_client.dart';

class AuthSession {
  final String token;
  final String role;
  final AppUser user;

  const AuthSession({
    required this.token,
    required this.role,
    required this.user,
  });
}

class AuthService {
  final ApiClient _api;

  AuthService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final body = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    return _sessionFromBody(body);
  }

  Future<AuthSession> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String gender,
    required String dob,
    String? medicalHistory,
    String role = 'patient',
    String? specialization,
    String? medicalCertificate,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'gender': gender,
      'dob': dob,
      'role': role,
      if (medicalHistory != null) 'medical_history': medicalHistory,
      if (specialization != null) 'specialization': specialization,
      if (medicalCertificate != null) 'medical_certificate': medicalCertificate,
    };
    final result = await _api.post('/auth/signup', body: body);
    return _sessionFromBody(result);
  }

  Future<void> deleteAccount({
    required String token,
    required String password,
  }) async {
    await _api.delete('/auth/me', token: token, body: {'password': password});
  }

  Future<AuthSession> fetchMe(String token) async {
    final body = await _api.get('/auth/me', token: token);
    return _sessionFromBody(body);
  }

  Future<void> requestDoctor({
    required String token,
    required String name,
    required String specialization,
  }) async {
    await _api.post('/auth/request-doctor', token: token, body: {
      'name': name,
      'specialization': specialization,
    });
  }

  Future<AppUser> updateProfile({
    required String token,
    String? name,
    String? phone,
    String? email,
    String? password,
    String? gender,
    String? dob,
    String? medicalHistory,
    String? specialization,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (gender != null) body['gender'] = gender;
    if (dob != null) body['dob'] = dob;
    if (medicalHistory != null) body['medical_history'] = medicalHistory;
    if (specialization != null) body['specialization'] = specialization;
    final response = await _api.patch('/auth/me', body: body, token: token);
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final userJson = data['user'] as Map<String, dynamic>? ?? {};
    final role =
        data['role'] as String? ?? userJson['role'] as String? ?? 'patient';
    return AppUser.fromJson({...userJson, 'role': role});
  }

  AuthSession _sessionFromBody(Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>? ?? body;
    final token = data['token'] as String? ?? '';
    final role = data['role'] as String? ?? 'patient';
    final userJson = data['user'] as Map<String, dynamic>? ?? {};
    if (token.isEmpty || userJson.isEmpty) {
      throw const ApiException('Authentication response was incomplete.');
    }
    final user = AppUser.fromJson({...userJson, 'role': role});
    return AuthSession(token: token, role: role, user: user);
  }
}
