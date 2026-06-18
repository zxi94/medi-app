import 'dart:io';
import 'package:flutter/foundation.dart';

/// Base URL for the MediScan backend API.
///
/// | Where you run the app | Set API_BASE_URL to |
/// |-----------------------|--------------------------------------|
/// | Laptop / desktop      | http://localhost:5001                |
/// | Android emulator      | http://10.0.2.2:5001                 |
/// | Physical phone + USB  | adb reverse tcp:5001 tcp:5001        |
/// | Physical phone Wi-Fi  | http://YOUR_LAPTOP_IP:5001           |
///
/// Examples:
///   adb reverse tcp:5001 tcp:5001
///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5001
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.42:5001
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5001
class ApiConfig {
  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) return _overrideBaseUrl;
    if (kIsWeb) return 'http://localhost:5001';
    return Platform.isAndroid ? 'http://10.0.2.2:5001' : 'http://localhost:5001';
  }
}
