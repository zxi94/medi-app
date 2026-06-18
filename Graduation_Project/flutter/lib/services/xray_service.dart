import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_client.dart';

class XrayRecord {
  final int id;
  final int patientId;
  final int? doctorId;
  final String imagePath;
  final DateTime? uploadDate;
  final Map<String, dynamic>? diagnosisOutput;
  final String? heatmapPath;
  final Map<String, dynamic>? aiReport;

  const XrayRecord({
    required this.id,
    required this.patientId,
    this.doctorId,
    required this.imagePath,
    this.uploadDate,
    this.diagnosisOutput,
    this.heatmapPath,
    this.aiReport,
  });

  factory XrayRecord.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? diagnosis;
    Map<String, dynamic>? report;
    final ri = json['result_image'];
    if (ri is Map<String, dynamic>) {
      diagnosis = ri['diagnosis_output'] as Map<String, dynamic>?;
      report = ri['ai_report'] as Map<String, dynamic>?;
    }

    return XrayRecord(
      id: _readInt(json['id']),
      patientId: _readInt(json['patient_id']),
      doctorId: _readNullableInt(json['doctor_id']),
      imagePath: json['image_path'] as String? ?? '',
      uploadDate: _readDate(json['upload_date']),
      diagnosisOutput: diagnosis,
      heatmapPath:
          ri is Map<String, dynamic> ? ri['heatmap_path'] as String? : null,
      aiReport: report,
    );
  }

  String get diagnosisLabel {
    if (diagnosisOutput == null) return 'Pending Analysis';
    return diagnosisOutput!['label'] as String? ??
        diagnosisOutput!['prediction'] as String? ??
        'Analyzed';
  }

  double get confidence {
    if (diagnosisOutput == null) return 0;
    return (diagnosisOutput!['confidence'] as num?)?.toDouble() ?? 0;
  }

  String get confidenceLabel {
    if (confidence == 0) return '';
    return '${(confidence * 100).toStringAsFixed(0)}%';
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _readNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _readDate(dynamic value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class XrayService {
  final ApiClient _api;

  XrayService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<XrayRecord>> fetchMyXrays(String token) async {
    final body = await _api.get('/api/history/my-xrays', token: token);
    final data = _readData(body);
    final xrays = data['xrays'] as List? ?? body['xrays'] as List? ?? const [];
    return xrays
        .whereType<Map<String, dynamic>>()
        .map(XrayRecord.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> fetchMyStats(String token) async {
    final body = await _api.get('/api/history/my-stats', token: token);
    return _readData(body);
  }

  Future<Map<String, dynamic>> fetchDoctorStats(String token) async {
    final body = await _api.get('/api/history/doctor-stats', token: token);
    return _readData(body);
  }

  Future<List<Map<String, dynamic>>> fetchDoctorPatients(String token) async {
    final body = await _api.get('/api/history/doctor-patients', token: token);
    final data = _readData(body);
    final patients =
        data['patients'] as List? ?? body['patients'] as List? ?? const [];
    return patients.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> uploadXray({
    required String token,
    required File file,
    int? patientId,
    String? language,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/xray/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    if (patientId != null) {
      request.fields['patient_id'] = patientId.toString();
    }
    if (language != null) {
      request.fields['language'] = language;
    }
    request.files.add(await http.MultipartFile.fromPath('xray', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['success'] == true) {
      return body;
    }

    throw ApiException(
      body['message'] as String? ?? 'Upload failed',
      statusCode: response.statusCode,
    );
  }
}

Map<String, dynamic> _readData(Map<String, dynamic> body) {
  final data = body['data'];
  if (data is Map<String, dynamic>) return data;
  return body;
}
