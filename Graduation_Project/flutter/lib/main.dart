import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';
import 'screens/auth/admin/admin_main.dart';
import 'screens/auth/admin/admin_dashboard_view.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/doctor/doctor_profile.dart';
import 'screens/shared/otp_verification_screen.dart';
import 'screens/auth/patient/patient_profile.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

import 'package:mediscan_ai/l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const MediScanApp(),
    ),
  );
}

class MediScanApp extends StatelessWidget {
  const MediScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();

    return MaterialApp(
      title: 'MediScan AI',
      debugShowCheckedModeBanner: false,

      // ── Locale & i18n ──────────────────────────────────────────
      locale: languageProvider.appLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ── Theme ──────────────────────────────────────────────────
      theme: AppTheme.theme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,

      // ── RTL / LTR Directionality ───────────────────────────────
      builder: (context, child) {
        return Directionality(
          textDirection:
              languageProvider.isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },

      // ── Routes ─────────────────────────────────────────────────
      home: const AuthScreen(),
      routes: {
        '/auth': (_) => const AuthScreen(),
        '/admin': (_) => const AdminMainScreen(),
        '/admin/dashboard': (_) => const AdminDashboardView(),
        '/doctor/profile': (_) => const DoctorProfileScreen(),
        '/patient/profile': (_) => const PatientProfileScreen(),
        '/otp': (_) => const OtpVerificationScreen(),
      },
    );
  }
}
