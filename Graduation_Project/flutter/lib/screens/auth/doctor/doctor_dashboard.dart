import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_client.dart';
import '../../../services/xray_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/shared_widgets.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final _service = XrayService();
  int _totalAnalyses = 0;
  int _pendingCount = 0;
  int _totalReports = 0;
  List<Map<String, dynamic>> _recentPatients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().refreshProfile();
      final stats = await _service.fetchDoctorStats(token);
      if (!mounted) return;
      setState(() {
        _totalAnalyses = (stats['totalAnalyses'] as num?)?.toInt() ?? 0;
        _totalReports = (stats['totalReports'] as num?)?.toInt() ?? 0;
        _pendingCount = (stats['pendingCount'] as num?)?.toInt() ?? 0;
        final recent = stats['recentXrays'] as List? ?? [];
        _recentPatients = recent.whereType<Map<String, dynamic>>().toList();
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;
    final name =
        (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'Doctor';
    final greetingName =
        name.toLowerCase().startsWith('dr') ? name : 'Dr. $name';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const SessionAppTopBar(onProfileTap: null, hideProfileMenu: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.25)),
                      ),
                      child: Text(_error!,
                          style: GoogleFonts.dmSans(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w600)),
                    ),
                  // Header
                  Text('Dashboard',
                      style: GoogleFonts.dmSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.headlineLarge?.color,
                      )),
                  const SizedBox(height: 4),
                  Text('Welcome back, $greetingName.',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      )),
                  const SizedBox(height: 16),
                  if (user?.verificationStatus == null ||
                      user?.verificationStatus == 'pending')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              size: 20, color: AppTheme.warning),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Account Pending Approval',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.warning)),
                                const SizedBox(height: 4),
                                Text(
                                    'Your account is awaiting admin verification. You will be able to access all features once approved.',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 12, color: AppTheme.warning)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Stats grid
                  if (_isLoading)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(48),
                            child: CircularProgressIndicator()))
                  else ...[
                    LayoutBuilder(builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio:
                            constraints.maxWidth > 600 ? 1.6 : 1.4,
                        children: [
                          StatCard(
                              title: 'Total Analyses',
                              value: '$_totalAnalyses',
                              icon: Icons.analytics_outlined),
                          StatCard(
                              title: 'Reports',
                              value: '$_totalReports',
                              icon: Icons.people_outline,
                              iconColor: const Color(0xFF7B61FF)),
                          StatCard(
                              title: 'Pending',
                              value: '$_pendingCount',
                              icon: Icons.pending_outlined,
                              iconColor: AppTheme.warning),
                          const StatCard(
                              title: 'Accuracy',
                              value: '98%',
                              icon: Icons.verified_outlined,
                              iconColor: AppTheme.success),
                        ],
                      );
                    }),

                    const SizedBox(height: 20),

                    // Recent Diagnoses
                    SectionCard(
                      title: 'Recent Diagnoses',
                      description: 'Latest AI-powered analysis',
                      child: _recentPatients.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('No recent analyses.',
                                  style: GoogleFonts.dmSans(
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.textSecondary)),
                            )
                          : Column(
                              children:
                                  _recentPatients.asMap().entries.map((entry) {
                                final i = entry.key;
                                final xray = entry.value;
                                final patient =
                                    xray['patient'] as Map<String, dynamic>?;
                                final name =
                                    patient?['name'] as String? ?? 'Unknown';
                                final date =
                                    xray['upload_date'] as String? ?? '';
                                final ri = xray['result_image']
                                    as Map<String, dynamic>?;
                                final diagnosis = ri?['diagnosis_output']
                                        ?['label'] as String? ??
                                    ri?['diagnosis_output']?['prediction']
                                        as String? ??
                                    'Pending';
                                return Column(
                                  children: [
                                    if (i > 0) const Divider(height: 20),
                                    _DiagnosisRow(
                                      initials: name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      name: name,
                                      date: date.isNotEmpty
                                          ? date.split('T')[0]
                                          : '',
                                      diagnosis: diagnosis,
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                    ),

                    const SizedBox(height: 16),

                    // Model Accuracy Trend
                    const SectionCard(
                      title: 'Model Accuracy Trend',
                      description: 'AI model performance',
                      child: SizedBox(height: 200, child: _AccuracyChart()),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagnosisRow extends StatelessWidget {
  final String initials;
  final String name;
  final String date;
  final String diagnosis;

  const _DiagnosisRow({
    required this.initials,
    required this.name,
    required this.date,
    required this.diagnosis,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        PatientAvatar(initials: initials),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color)),
              Text(date,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  )),
            ],
          ),
        ),
        DiagnosisBadge(label: diagnosis, type: diagnosisToType(diagnosis)),
      ],
    );
  }
}

class _AccuracyChart extends StatelessWidget {
  const _AccuracyChart();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gridColor = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: gridColor,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: textColor,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                const months = ['Jun', 'Jul', 'Aug', 'Sep', 'Oct'];
                if (v.toInt() >= 0 && v.toInt() < months.length) {
                  return Text(
                    months[v.toInt()],
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: textColor,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 4,
        minY: 80,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 85),
              FlSpot(1, 89),
              FlSpot(2, 93),
              FlSpot(3, 97),
              FlSpot(4, 98),
            ],
            isCurved: true,
            color: AppTheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 5,
                color: theme.cardTheme.color ?? Colors.white,
                strokeColor: AppTheme.primary,
                strokeWidth: 2,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}
