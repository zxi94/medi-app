import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  AuthStatus status = AuthStatus.initial;
  AppUser? user;
  String? token;
  String? role;
  String? errorMessage;

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  bool get isAdmin =>
      role?.toLowerCase() == 'admin' ||
      user?.role.toLowerCase() == 'admin' ||
      (user?.isAdmin ?? false);

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    return _run(() => _authService.login(email: email, password: password));
  }

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    String gender = 'other',
    String? dob,
    String role = 'patient',
    String? medicalHistory,
    String? specialization,
    String? medicalCertificate,
  }) async {
    return _run(() => _authService.signup(
          name: name,
          email: email,
          password: password,
          phone: phone,
          gender: gender,
          dob: dob ?? DateTime.now().toIso8601String().split('T').first,
          medicalHistory: medicalHistory,
          role: role,
          specialization: specialization,
          medicalCertificate: medicalCertificate,
        ));
  }

  Future<bool> requestDoctor({
    required String name,
    required String specialization,
  }) async {
    if (token == null) return false;
    try {
      await _authService.requestDoctor(
          token: token!, name: name, specialization: specialization);
      await refreshProfile();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? email,
    String? password,
    String? gender,
    String? dob,
    String? medicalHistory,
    String? specialization,
  }) async {
    if (token == null) return false;
    try {
      final updated = await _authService.updateProfile(
        token: token!,
        name: name,
        phone: phone,
        email: email,
        password: password,
        gender: gender,
        dob: dob,
        medicalHistory: medicalHistory,
        specialization: specialization,
      );
      user = updated;
      role = updated.role;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshProfile() async {
    if (token == null) return;
    try {
      final session = await _authService.fetchMe(token!);
      token = session.token;
      user = session.user;
      role = session.role;
      notifyListeners();
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount({required String password}) async {
    if (token == null) return false;
    try {
      await _authService.deleteAccount(token: token!, password: password);
      logout();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _run(Future<AuthSession> Function() action) async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final session = await action();
      token = session.token;
      role = session.role;
      user = session.user;
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      status = AuthStatus.error;
      errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      status = AuthStatus.error;
      errorMessage = 'Unable to reach the server. Check your connection.';
      notifyListeners();
      return false;
    }
  }

  void logout() {
    token = null;
    role = null;
    user = null;
    errorMessage = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
