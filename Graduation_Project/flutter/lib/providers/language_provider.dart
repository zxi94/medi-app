import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app's current locale and persists it across sessions.
///
/// Usage in widget tree:
///   final lang = context.watch<LanguageProvider>();
///   lang.updateLanguage('ar');
class LanguageProvider extends ChangeNotifier {
  Locale _appLocale = const Locale('en');
  bool _initialized = false;

  Locale get appLocale => _appLocale;
  bool get isInitialized => _initialized;
  bool get isRTL => _appLocale.languageCode == 'ar';
  String get languageCode => _appLocale.languageCode;

  LanguageProvider() {
    _loadPersistedLanguage();
  }

  Future<void> _loadPersistedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('appLanguage') ?? 'en';
      _appLocale = Locale(saved);
    } catch (_) {
      _appLocale = const Locale('en');
    }
    _initialized = true;
    notifyListeners();
  }

  /// Update the app language and persist the choice.
  Future<void> updateLanguage(String languageCode) async {
    if (_appLocale.languageCode == languageCode) return;
    _appLocale = Locale(languageCode);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('appLanguage', languageCode);
    } catch (_) {
      // Non-fatal — preference didn't save but UI updated in memory
    }
  }

  /// Toggle between Arabic and English.
  Future<void> toggleLanguage() async {
    await updateLanguage(isRTL ? 'en' : 'ar');
  }
}
