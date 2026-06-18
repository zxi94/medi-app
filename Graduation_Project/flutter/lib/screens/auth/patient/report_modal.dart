import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/xray_service.dart';
import '../../../config/api_config.dart';

class ReportModal extends StatelessWidget {
  final XrayRecord record;

  const ReportModal({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final aiReport = record.aiReport ?? {};
    final fullReport =
        aiReport['full_report'] ?? 'Report generation pending or failed.';

    // We can display the original image and heatmap
    final imageUrl =
        '${ApiConfig.baseUrl}/${record.imagePath.replaceAll("\\", "/")}';
    final heatmapUrl = record.heatmapPath != null
        ? '${ApiConfig.baseUrl}/${record.heatmapPath!.replaceAll("\\", "/")}'
        : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBg : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Diagnostic Report',
                  style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: theme.textTheme.headlineSmall?.color)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('X-Ray Images',
                      style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.titleMedium?.color)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('Original',
                                style: GoogleFonts.dmSans(fontSize: 13)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(imageUrl,
                                  height: 180,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image, size: 50)),
                            ),
                          ],
                        ),
                      ),
                      if (heatmapUrl != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              Text('AI Attention Map',
                                  style: GoogleFonts.dmSans(fontSize: 13)),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(heatmapUrl,
                                    height: 180,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image,
                                        size: 50)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Detailed AI Report',
                      style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.titleMedium?.color)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkBackground
                          : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark
                              ? AppTheme.darkBorderColor
                              : AppTheme.borderColor),
                    ),
                    child: SelectableText(
                      fullReport,
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          height: 1.6,
                          color: theme.textTheme.bodyLarge?.color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
