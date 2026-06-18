import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mediscan_ai/l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class AlertUtils {
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(context, message, Icons.check_circle_outline, Colors.green);
  }

  static void showError(BuildContext context, String message) {
    _showSnackBar(context, message, Icons.error_outline, AppTheme.error);
  }

  static void showWarning(BuildContext context, String message) {
    _showSnackBar(context, message, Icons.warning_amber_rounded, Colors.orange);
  }

  static void showInfo(BuildContext context, String message) {
    _showSnackBar(context, message, Icons.info_outline, AppTheme.primary);
  }

  static void _showSnackBar(
      BuildContext context, String message, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.dmSans(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.5), width: 1),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 4,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
  }) async {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              title,
              style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
            ),
            content: Text(
              content,
              style: GoogleFonts.dmSans(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  cancelText ?? loc.cancel,
                  style: GoogleFonts.dmSans(
                    color: theme.brightness == Brightness.dark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDestructive ? AppTheme.error : AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  confirmText ?? loc.ok,
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  static void showLoadingDialog(BuildContext context, {String? message}) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(width: 24),
              Text(
                message ?? loc.loading,
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
