import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mediscan_ai/l10n/app_localizations.dart';
import '../theme/theme_provider.dart';
import '../theme/app_theme.dart';

/// Drop this widget anywhere in your app (e.g. doctor_profile.dart or patient_profile.dart)
/// inside a SectionCard to let users switch themes.
///
/// Usage:
///   const ThemeSwitcher()
class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            loc.profileAppearance,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
        _ModeOption(
          icon: Icons.wb_sunny_outlined,
          label: loc.lightMode,
          subtitle: loc.lightModeDesc,
          isSelected: provider.isLight,
          onTap: provider.setLight,
        ),
        const SizedBox(height: 8),
        _ModeOption(
          icon: Icons.dark_mode_outlined,
          label: loc.darkMode,
          subtitle: loc.darkModeDesc,
          isSelected: provider.isDark,
          onTap: provider.setDark,
        ),
        const SizedBox(height: 8),
        _ModeOption(
          icon: Icons.phone_android_outlined,
          label: loc.systemDefault,
          subtitle: loc.systemDefaultDesc,
          isSelected: provider.isSystem,
          onTap: provider.setSystem,
        ),
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : (isDark ? AppTheme.darkInputBg : AppTheme.inputBg),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppTheme.primary
                  : (isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primary
                          : (isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 18, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}
