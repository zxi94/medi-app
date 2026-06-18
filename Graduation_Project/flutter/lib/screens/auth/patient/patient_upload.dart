import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mediscan_ai/l10n/app_localizations.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/api_client.dart';
import '../../../services/xray_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/shared_widgets.dart';

class PatientUploadScreen extends StatefulWidget {
  const PatientUploadScreen({super.key});

  @override
  State<PatientUploadScreen> createState() => _PatientUploadScreenState();
}

class _PatientUploadScreenState extends State<PatientUploadScreen> {
  static const int _maxUploadBytes = 10 * 1024 * 1024;
  final _service = XrayService();
  final _picker = ImagePicker();
  File? _selectedFile;
  String? _fileName;
  int? _fileSizeBytes;
  bool _isSubmitting = false;

  Future<void> _pickFile() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return;
    final file = File(picked.path);
    final size = await file.length();
    if (size > _maxUploadBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Image is ${_formatBytes(size)}. Maximum upload size is 10 MB.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() {
      _selectedFile = file;
      _fileName = picked.name;
      _fileSizeBytes = size;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _submit() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || _selectedFile == null) return;

    setState(() => _isSubmitting = true);
    final loc = AppLocalizations.of(context);
    try {
      final langCode = loc?.localeName == 'ar' ? 'ar' : 'en';
      await _service.uploadXray(
          token: token, file: _selectedFile!, language: langCode);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _selectedFile = null;
        _fileName = null;
        _fileSizeBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              loc?.uploadSuccessMsg ??
                  'X-ray uploaded successfully! AI analysis will begin shortly.',
              style: GoogleFonts.dmSans()),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: GoogleFonts.dmSans()),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              loc?.uploadFailedMsg ?? 'Upload failed. Check your connection.',
              style: GoogleFonts.dmSans()),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: const SessionAppTopBar(hideProfileMenu: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc?.uploadXrayTitle ?? 'Upload X-ray',
                style: GoogleFonts.dmSans(
                    fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
                loc?.uploadXrayDescPatient ??
                    'Share your X-ray images with your doctor',
                style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary)),
            const SizedBox(height: 20),
            // Upload card
            SectionCard(
              title: loc?.uploadImageLabel ?? 'Upload Image',
              description: loc?.uploadImageHint ??
                  'Select a clear X-ray image up to 10 MB',
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedFile == null)
                    UploadDropzone(onTap: _pickFile)
                  else
                    Column(
                      children: [
                        Container(
                          height: 320,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.image,
                                  size: 64, color: Colors.white30),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _selectedFile!,
                                  width: double.infinity,
                                  height: 320,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image,
                                    size: 64,
                                    color: Colors.white30,
                                  ),
                                ),
                              ),
                              Positioned(
                                  top: 12,
                                  right: 12,
                                  child: DiagnosisBadge(
                                      label: _fileName ?? 'xray_image.jpg',
                                      type: BadgeType.success)),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _selectedFile = null;
                            _fileName = null;
                            _fileSizeBytes = null;
                          }),
                          icon: const Icon(Icons.close, size: 14),
                          label: Text(loc?.removeImage ?? 'Remove file'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _selectedFile != null ? _submit : null,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(
                    _isSubmitting
                        ? (loc?.uploadingText ?? 'Uploading...')
                        : 'Submit for Review',
                    style: GoogleFonts.dmSans(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            if (_selectedFile != null) ...[
              const SizedBox(height: 8),
              Text(
                'Selected file: ${_fileName ?? 'X-ray'} (${_formatBytes(_fileSizeBytes ?? 0)})',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            // What happens next
            SectionCard(
              title: loc?.whatHappensNext ?? 'What happens next?',
              child: Column(
                children: [
                  _StepItem(
                      number: '1',
                      title: loc?.aiAnalysisTitle ?? 'AI Analysis',
                      description: loc?.aiAnalysisDesc ??
                          'Your X-ray will be analyzed by our AI system to detect any potential issues.'),
                  const Divider(height: 20),
                  _StepItem(
                      number: '2',
                      title: loc?.doctorReviewTitle ?? 'Doctor Review',
                      description: loc?.doctorReviewDesc ??
                          'A qualified doctor will review the AI results and provide their assessment.'),
                  const Divider(height: 20),
                  _StepItem(
                      number: '3',
                      title: loc?.getResultsTitle ?? 'Get Results',
                      description: loc?.getResultsDesc ??
                          "You'll receive a detailed report with diagnosis and recommendations."),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_outlined,
                      size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text('Typical review time: 24-48 hours',
                      style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Guidelines
            const SectionCard(
              title: 'Important Guidelines',
              child: Column(
                children: [
                  _GuidelineRow(
                      'Ensure the X-ray image is clear and properly oriented.'),
                  SizedBox(height: 8),
                  _GuidelineRow(
                      'Accepted formats: JPG, PNG, JPEG, or DICOM up to 10 MB.'),
                  SizedBox(height: 8),
                  _GuidelineRow(
                      'Include all relevant symptoms and medical history.'),
                  SizedBox(height: 8),
                  _GuidelineRow(
                      'This is not a substitute for emergency medical care.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}

class _StepItem extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _StepItem(
      {required this.number, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
              color: AppTheme.primary, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(number,
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.dmSans(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(description,
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuidelineRow extends StatelessWidget {
  final String text;
  const _GuidelineRow(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline,
            size: 16, color: AppTheme.success),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                    height: 1.4))),
      ],
    );
  }
}
