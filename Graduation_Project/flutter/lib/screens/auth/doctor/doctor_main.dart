import 'package:flutter/material.dart';
import 'package:mediscan_ai/l10n/app_localizations.dart';

import '../../../theme/app_theme.dart';
import '../../shared/care_chat_screen.dart';
import 'doctor_dashboard.dart';
import 'doctor_upload.dart';
import 'doctor_patients.dart';
import 'doctor_profile.dart';
import 'doctor_chatbot.dart';

class DoctorMainScreen extends StatefulWidget {
  const DoctorMainScreen({super.key});

  @override
  State<DoctorMainScreen> createState() => _DoctorMainScreenState();
}

class _DoctorMainScreenState extends State<DoctorMainScreen> {
  int _currentIndex = 0;
  int _patientsRefreshKey = 0;
  int _chatRefreshKey = 0;

  void _selectIndex(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 2) _patientsRefreshKey++;
      if (index == 3) _chatRefreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;
    final loc = AppLocalizations.of(context)!;
    final screens = [
      const DoctorDashboard(),
      const DoctorUploadScreen(),
      DoctorPatientsScreen(refreshKey: _patientsRefreshKey),
      CareChatScreen(refreshKey: _chatRefreshKey),
      const DoctorChatbotScreen(),
      const DoctorProfileScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _selectIndex,
              labelType: NavigationRailLabelType.all,
              backgroundColor: theme.cardTheme.color,
              indicatorColor: AppTheme.primary.withValues(alpha: 0.1),
              selectedIconTheme: const IconThemeData(color: AppTheme.primary),
              unselectedIconTheme:
                  IconThemeData(color: theme.textTheme.bodySmall?.color),
              selectedLabelTextStyle: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
              unselectedLabelTextStyle: TextStyle(
                  color: theme.textTheme.bodySmall?.color, fontSize: 12),
              destinations: [
                NavigationRailDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    label: Text(loc.navHome)),
                NavigationRailDestination(
                    icon: const Icon(Icons.upload_file_outlined),
                    selectedIcon: const Icon(Icons.upload_file),
                    label: Text(loc.navUpload)),
                NavigationRailDestination(
                    icon: const Icon(Icons.people_outline),
                    selectedIcon: const Icon(Icons.people),
                    label: Text(loc.navPatients)),
                NavigationRailDestination(
                    icon: const Icon(Icons.forum_outlined),
                    selectedIcon: const Icon(Icons.forum),
                    label: Text(loc.navChat)),
                NavigationRailDestination(
                    icon: const Icon(Icons.smart_toy_outlined),
                    selectedIcon: const Icon(Icons.smart_toy),
                    label: Text(loc.navAI)),
                NavigationRailDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(Icons.person),
                    label: Text(loc.navProfile)),
              ],
            ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: screens),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                border: Border(
                    top: BorderSide(
                        color: isDark
                            ? AppTheme.darkBorderColor
                            : AppTheme.borderColor)),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 12,
                      offset: Offset(0, -2)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home,
                          label: loc.navHome,
                          index: 0,
                          current: _currentIndex,
                          onTap: _selectIndex),
                      _NavItem(
                          icon: Icons.upload_file_outlined,
                          activeIcon: Icons.upload_file,
                          label: loc.navUpload,
                          index: 1,
                          current: _currentIndex,
                          onTap: _selectIndex),
                      _NavItem(
                          icon: Icons.people_outline,
                          activeIcon: Icons.people,
                          label: loc.navPatients,
                          index: 2,
                          current: _currentIndex,
                          onTap: _selectIndex),
                      _NavItem(
                          icon: Icons.forum_outlined,
                          activeIcon: Icons.forum,
                          label: loc.navChat,
                          index: 3,
                          current: _currentIndex,
                          onTap: _selectIndex),
                      _NavItem(
                          icon: Icons.smart_toy_outlined,
                          activeIcon: Icons.smart_toy,
                          label: loc.navAI,
                          index: 4,
                          current: _currentIndex,
                          onTap: _selectIndex),
                      _NavItem(
                          icon: Icons.person_outline,
                          activeIcon: Icons.person,
                          label: loc.navProfile,
                          index: 5,
                          current: _currentIndex,
                          onTap: _selectIndex),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final Function(int) onTap;

  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      required this.index,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = index == current;
    final color = isActive
        ? AppTheme.primary
        : (theme.textTheme.bodySmall?.color ?? AppTheme.textSecondary);

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isActive
            ? BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'DM Sans',
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
