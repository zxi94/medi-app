import 'package:flutter/material.dart';
import 'package:mediscan_ai/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Compact pill badge shown next to user names when [isAdmin] is true.
class AdminBadge extends StatelessWidget {
  final bool isAdmin;
  final bool compact;
  final bool isLoading;

  const AdminBadge({
    super.key,
    required this.isAdmin,
    this.compact = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: compact ? 48 : 64,
        height: compact ? 20 : 24,
        child: const Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!isAdmin) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF3D2E00) : AppTheme.badgeOrange;
    final fg = isDark ? const Color(0xFFFFB74D) : AppTheme.badgeOrangeFg;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, size: compact ? 12 : 14, color: fg),
          SizedBox(width: compact ? 3 : 5),
          Text(
            AppLocalizations.of(context)?.profileAdmin ?? 'Admin',
            style: GoogleFonts.dmSans(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays a user name with an optional admin badge inline.
class UserNameWithBadge extends StatelessWidget {
  final String name;
  final bool isAdmin;
  final bool isLoading;
  final TextStyle? nameStyle;
  final double spacing;

  const UserNameWithBadge({
    super.key,
    required this.name,
    required this.isAdmin,
    this.isLoading = false,
    this.nameStyle,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing,
      runSpacing: 4,
      children: [
        Text(name, style: nameStyle),
        AdminBadge(isAdmin: isAdmin, isLoading: isLoading),
      ],
    );
  }
}
