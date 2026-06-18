import 'package:flutter/material.dart';
import 'package:mediscan_ai/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'admin_badge.dart';

/// App top bar with logo
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String userInitials;
  final bool showBack;
  final VoidCallback? onProfileTap;
  final bool isAdmin;
  final bool isAdminLoading;
  final String role;
  final bool hideProfileMenu;

  const AppTopBar({
    super.key,
    required this.userInitials,
    this.showBack = false,
    this.onProfileTap,
    this.isAdmin = false,
    this.isAdminLoading = false,
    this.role = 'patient',
    this.hideProfileMenu = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Container(
        height: preferredSize.height,
        color: theme.appBarTheme.backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (showBack)
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new,
                    size: 18, color: theme.iconTheme.color),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            const _LogoWidget(),
            const Spacer(),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_outlined,
                      size: 20,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary),
                  onPressed: () {},
                ),
                const SizedBox(width: 4),
                AdminBadge(
                  isAdmin: isAdmin,
                  isLoading: isAdminLoading,
                  compact: true,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Account menu',
                  offset: const Offset(0, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'profile') {
                      if (onProfileTap != null) {
                        onProfileTap!();
                        return;
                      }
                      final route = role.toLowerCase() == 'doctor'
                          ? '/doctor/profile'
                          : role.toLowerCase() == 'admin'
                              ? '/admin'
                              : '/patient/profile';
                      Navigator.of(context).pushNamed(route);
                    }
                    if (value == 'admin') {
                      Navigator.of(context).pushNamed('/admin');
                    }
                    if (value == 'logout') {
                      context.read<AuthProvider>().logout();
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/auth', (_) => false);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!hideProfileMenu)
                      PopupMenuItem(
                        value: 'profile',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.manage_accounts_outlined),
                          title: Text(
                              AppLocalizations.of(context)!.profileSettings),
                        ),
                      ),
                    if (!hideProfileMenu && isAdmin)
                      PopupMenuItem(
                        value: 'admin',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.admin_panel_settings_outlined),
                          title:
                              Text(AppLocalizations.of(context)!.adminConsole),
                        ),
                      ),
                    if (!hideProfileMenu) const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.logout, color: AppTheme.error),
                        title: Text(AppLocalizations.of(context)!.logout),
                      ),
                    ),
                  ],
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      userInitials,
                      style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

/// Top bar that reads the signed-in user from [AuthProvider].
class SessionAppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBack;
  final VoidCallback? onProfileTap;
  final bool hideProfileMenu;

  const SessionAppTopBar({
    super.key,
    this.showBack = false,
    this.onProfileTap,
    this.hideProfileMenu = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return AppTopBar(
          userInitials: auth.user?.initials ?? '?',
          showBack: showBack,
          onProfileTap: onProfileTap,
          isAdmin: auth.isAdmin,
          isAdminLoading: auth.isLoading,
          role: (auth.role ?? auth.user?.role ?? 'patient').toLowerCase(),
          hideProfileMenu: hideProfileMenu,
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

class _LogoWidget extends StatelessWidget {
  const _LogoWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: const Text('AI',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
        const SizedBox(width: 8),
        Text('MediScan AI',
            style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.titleLarge?.color)),
      ],
    );
  }
}

/// Stat card widget
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    BoxBorder? cardBorder;
    final shape = theme.cardTheme.shape;
    if (shape is RoundedRectangleBorder) {
      cardBorder = Border.fromBorderSide(shape.side);
    } else {
      cardBorder = Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.borderColor);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: cardBorder,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary)),
              ),
              Icon(icon, size: 18, color: iconColor ?? AppTheme.primary),
            ],
          ),
          const SizedBox(height: 14),
          Text(value,
              style: GoogleFonts.dmSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: theme.textTheme.headlineSmall?.color)),
        ],
      ),
    );
  }
}

/// Badge widget
class DiagnosisBadge extends StatelessWidget {
  final String label;
  final BadgeType type;

  const DiagnosisBadge(
      {super.key, required this.label, this.type = BadgeType.info});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _getColors(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: colors.$1, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.dmSans(
              fontSize: 12, fontWeight: FontWeight.w600, color: colors.$2)),
    );
  }

  (Color, Color) _getColors(bool isDark) {
    switch (type) {
      case BadgeType.warning:
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100));
      case BadgeType.success:
        return isDark
            ? (
                const Color(0xFF1B5E20).withValues(alpha: 0.2),
                const Color(0xFF81C784)
              )
            : (const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
      case BadgeType.error:
        return isDark
            ? (
                const Color(0xFFB71C1C).withValues(alpha: 0.2),
                const Color(0xFFE57373)
              )
            : (const Color(0xFFFFEBEE), const Color(0xFFC62828));
      case BadgeType.pending:
        return (const Color(0xFFFFF8E1), const Color(0xFFF57F17));
      case BadgeType.reviewing:
        return (const Color(0xFFE3F2FD), const Color(0xFF1565C0));
      case BadgeType.info:
        return isDark
            ? (AppTheme.primary.withValues(alpha: 0.2), AppTheme.primaryLight)
            : (const Color(0xFFE0F2F1), AppTheme.primary);
    }
  }
}

enum BadgeType { info, success, warning, error, pending, reviewing }

BadgeType diagnosisToType(String diagnosis) {
  switch (diagnosis.toLowerCase()) {
    case 'normal':
      return BadgeType.success;
    case 'pneumonia':
      return BadgeType.error;
    case 'tuberculosis':
      return BadgeType.warning;
    case 'completed':
      return BadgeType.success;
    case 'reviewing':
      return BadgeType.reviewing;
    case 'pending':
      return BadgeType.pending;
    default:
      return BadgeType.info;
  }
}

/// Section card
class SectionCard extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  final EdgeInsets? padding;

  const SectionCard({
    super.key,
    required this.title,
    this.description,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    BoxBorder? cardBorder;
    final shape = theme.cardTheme.shape;
    if (shape is RoundedRectangleBorder) {
      cardBorder = Border.fromBorderSide(shape.side);
    } else {
      cardBorder = Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.borderColor);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty || description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(title,
                        style: GoogleFonts.dmSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: theme.textTheme.titleLarge?.color)),
                  if (description != null) ...[
                    if (title.isNotEmpty) const SizedBox(height: 4),
                    Text(description!,
                        style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
          Padding(padding: padding ?? const EdgeInsets.all(24), child: child),
        ],
      ),
    );
  }
}

/// Patient avatar
class PatientAvatar extends StatelessWidget {
  final String initials;
  final double radius;
  final Color? backgroundColor;

  const PatientAvatar({
    super.key,
    required this.initials,
    this.radius = 18,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ?? AppTheme.primary.withValues(alpha: 0.1),
      child: Text(initials,
          style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary)),
    );
  }
}

/// XRay card
class XRayCard extends StatelessWidget {
  final String title;
  final String date;
  final String diagnosis;
  final String aiConfidence;
  final VoidCallback onTap;

  const XRayCard({
    super.key,
    required this.title,
    required this.date,
    required this.diagnosis,
    required this.aiConfidence,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    BoxBorder? cardBorder;
    final shape = theme.cardTheme.shape;
    if (shape is RoundedRectangleBorder) {
      cardBorder = Border.fromBorderSide(shape.side);
    } else {
      cardBorder = Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.borderColor);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: cardBorder,
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1A2E),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: CustomPaint(
                        painter: _XRayPainter(), size: Size.infinite),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: DiagnosisBadge(
                        label: diagnosis, type: diagnosisToType(diagnosis)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title,
                          style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.titleMedium?.color)),
                      Text(aiConfidence,
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 12,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(date,
                          style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _XRayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 1; i <= 6; i++) {
      final y = size.height * i / 7;
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset(size.width / 2, y),
              width: size.width * 0.7,
              height: 30),
          0,
          3.14,
          false,
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Chat bubble
class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final String time;

  const ChatBubble(
      {super.key,
      required this.message,
      required this.isUser,
      required this.time});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: const Icon(Icons.smart_toy_outlined,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primary
                    : (isDark ? AppTheme.darkRowBg : const Color(0xFFF3F3F5)),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: isUser ? null : const Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message,
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: isUser
                              ? Colors.white
                              : (isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary))),
                  const SizedBox(height: 4),
                  Text(time,
                      style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : (isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary))),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Legend item
class LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String percentage;

  const LegendItem(
      {super.key,
      required this.color,
      required this.label,
      required this.percentage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: theme.textTheme.bodyMedium?.color))),
        Text(percentage,
            style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.brightness == Brightness.dark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textPrimary)),
      ],
    );
  }
}

/// Toggle setting row
class SettingToggleRow extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool initialValue;

  const SettingToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.initialValue = true,
  });

  @override
  State<SettingToggleRow> createState() => _SettingToggleRowState();
}

class _SettingToggleRowState extends State<SettingToggleRow> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(height: 2),
                Text(widget.subtitle,
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary)),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: _value,
              onChanged: (v) => setState(() => _value = v),
              activeThumbColor: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Upload dropzone
class UploadDropzone extends StatelessWidget {
  final VoidCallback onTap;

  const UploadDropzone({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxWidth > 600 ? 300.0 : 240.0;
          return Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark
                      ? AppTheme.darkBorderColor
                      : AppTheme.primary.withValues(alpha: 0.3),
                  width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.cloud_upload_outlined,
                      size: 28, color: AppTheme.primary),
                ),
                const SizedBox(height: 16),
                Text('Drop X-ray image here',
                    style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.titleMedium?.color)),
                const SizedBox(height: 4),
                Text('or click to browse files',
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary)),
                const SizedBox(height: 12),
                Text('Supports: JPG, PNG, DICOM',
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary)),
              ],
            ),
          );
        },
      ),
    );
  }
}
