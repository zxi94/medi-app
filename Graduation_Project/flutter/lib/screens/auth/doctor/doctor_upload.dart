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
import '../../../utils/alert_utils.dart';
import '../../../widgets/shared_widgets.dart';

class DoctorUploadScreen extends StatefulWidget {
  const DoctorUploadScreen({super.key});

  @override
  State<DoctorUploadScreen> createState() => _DoctorUploadScreenState();
}

class _DoctorUploadScreenState extends State<DoctorUploadScreen> {
  final _service = XrayService();
  final _picker = ImagePicker();
  File? _selectedFile;
  String? _fileName;
  bool _isUploading = false;
  int? _selectedPatientId;
  List<Map<String, dynamic>> _patients = [];
  bool _loadingPatients = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPatients());
  }

  Future<void> _loadPatients() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final patients = await _service.fetchDoctorPatients(token);
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _loadingPatients = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPatients = false);
    }
  }

  Future<void> _pickFile() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return;
    setState(() {
      _selectedFile = File(picked.path);
      _fileName = picked.name;
    });
  }

  Future<void> _submit() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || _selectedFile == null) return;

    setState(() => _isUploading = true);
    final loc = AppLocalizations.of(context);
    try {
      final langCode = loc?.localeName == 'ar' ? 'ar' : 'en';
      await _service.uploadXray(
        token: token,
        file: _selectedFile!,
        patientId: _selectedPatientId,
        language: langCode,
      );
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _selectedFile = null;
        _fileName = null;
        _selectedPatientId = null;
      });
      AlertUtils.showSuccess(
          context,
          loc?.uploadSuccessMsg ??
              'X-ray uploaded. AI analysis will begin shortly.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      AlertUtils.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      AlertUtils.showError(context, loc?.uploadFailedMsg ?? 'Upload failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txtSec = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final auth = context.watch<AuthProvider>();
    final isPending = auth.user?.verificationStatus == null ||
        auth.user?.verificationStatus == 'pending';

    final loc = AppLocalizations.of(context);

    if (isPending) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: const SessionAppTopBar(hideProfileMenu: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline,
                    size: 48, color: AppTheme.warning),
                const SizedBox(height: 16),
                Text(loc?.accountPendingTitle ?? 'Account Pending Approval',
                    style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.warning)),
                const SizedBox(height: 8),
                Text(
                    loc?.accountPendingDesc ??
                        'Your account is awaiting admin verification. You will be able to upload X-rays once approved.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 14, color: txtSec)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const SessionAppTopBar(hideProfileMenu: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc?.uploadXrayTitle ?? 'Upload X-ray',
                style: GoogleFonts.dmSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: theme.textTheme.headlineLarge?.color,
                )),
            const SizedBox(height: 4),
            Text(loc?.uploadXrayDescDoctor ?? 'Upload for AI analysis',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: txtSec,
                )),
            const SizedBox(height: 20),
            SectionCard(
              title: loc?.uploadImageLabel ?? 'Upload Image',
              description: loc?.uploadImageHintDoctor ??
                  'Drag and drop or click to select',
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_selectedFile == null) ...[
                    UploadDropzone(onTap: _pickFile),
                  ] else ...[
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.image,
                              size: 64, color: Colors.white30),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: DiagnosisBadge(
                                label: _fileName ?? 'xray.jpg',
                                type: BadgeType.info),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _selectedFile = null;
                        _fileName = null;
                      }),
                      icon: const Icon(Icons.close, size: 16),
                      label: Text(loc?.removeImage ?? 'Remove'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Patient selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc?.selectPatientLabel ?? 'Select Patient',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.titleMedium?.color,
                          )),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: _loadingPatients
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : DropdownButton<int>(
                                  value: _selectedPatientId,
                                  isExpanded: true,
                                  dropdownColor: theme.cardTheme.color,
                                  hint: Text(
                                      loc?.selectPatientHint ??
                                          'Select a patient',
                                      style: GoogleFonts.dmSans(
                                          color: txtSec, fontSize: 14)),
                                  style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      color: theme.textTheme.bodyLarge?.color),
                                  items: _patients
                                      .map((p) => DropdownMenuItem(
                                            value: p['id'] as int?,
                                            child: Text(p['name'] as String? ??
                                                'Unknown'),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedPatientId = v),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: (_selectedFile != null) ? _submit : null,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload, size: 18),
                      label: Text(
                          _isUploading
                              ? (loc?.uploadingText ?? 'Uploading...')
                              : (loc?.uploadXrayTitle ?? 'Upload X-ray'),
                          style: GoogleFonts.dmSans(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
