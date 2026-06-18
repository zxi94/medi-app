import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/chat_models.dart';
import 'api_client.dart';

/// Model for a pending OTP connection request sent to this patient by a doctor.
class PendingConnection {
  final int doctorId;
  final String doctorName;
  final DateTime expiresAt;

  const PendingConnection({
    required this.doctorId,
    required this.doctorName,
    required this.expiresAt,
  });

  factory PendingConnection.fromJson(Map<String, dynamic> json) {
    return PendingConnection(
      doctorId: _readInt(json['doctorId']),
      doctorName: json['doctorName'] as String? ?? 'Your doctor',
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.now().add(const Duration(minutes: 10)),
    );
  }
}

class ChatService {
  final ApiClient _api;
  final http.Client _streamClient;

  ChatService({ApiClient? api, http.Client? streamClient})
      : _api = api ?? ApiClient(),
        _streamClient = streamClient ?? http.Client();

  Future<List<ChatContact>> fetchContacts(String token) async {
    final body = await _api.get('/api/chat/contacts', token: token);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final contacts = data['contacts'] as List? ?? const [];
    return contacts
        .whereType<Map<String, dynamic>>()
        .map(ChatContact.fromJson)
        .toList();
  }

  Future<List<ChatThread>> fetchThreads(String token) async {
    final body = await _api.get('/api/chat/threads', token: token);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final threads = data['threads'] as List? ?? const [];
    return threads
        .whereType<Map<String, dynamic>>()
        .map(ChatThread.fromJson)
        .toList();
  }

  /// Used during new patient registration to link with a doctor via a code.
  Future<void> verifyConnection({
    required String token,
    required String code,
  }) async {
    await _api.post(
      '/api/chat/connections/verify',
      token: token,
      body: {'code': code},
    );
  }

  /// Doctor calls this to send a WhatsApp OTP to a patient by phone number.
  /// On success the backend sends the OTP and returns 200; no code is returned
  /// to the doctor's UI.
  Future<void> sendConnectionRequest({
    required String token,
    required String phone,
  }) async {
    await _api.post(
      '/api/chat/initiate-handshake',
      token: token,
      body: {'phone': phone},
    );
  }

  /// Patient calls this to check if a doctor has sent a pending OTP.
  /// Returns null if no pending connection exists.
  Future<PendingConnection?> fetchPendingConnection(String token) async {
    try {
      final body = await _api.get('/api/otp/pending', token: token);
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final pending = data['pending'];
      if (pending == null) return null;
      return PendingConnection.fromJson(pending as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Patient submits the OTP to confirm the doctor-patient connection.
  /// Returns the chatThreadId so the UI can navigate directly into Chat.
  Future<int> verifyPendingConnection({
    required String token,
    required String otp,
    required int doctorId,
  }) async {
    final body = await _api.post(
      '/api/otp/verify',
      token: token,
      body: {'otp': otp, 'doctorId': doctorId},
    );
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return _readInt(data['chatThreadId']);
  }

  Future<Map<String, dynamic>> sendOtp({
    required String token,
    required String phone,
  }) async {
    final body = await _api.post(
      '/api/otp/send',
      token: token,
      body: {'phone': phone},
    );
    return body;
  }

  /// Phone-number verification (used by OtpVerificationScreen only).
  Future<void> verifyOtp({
    required String phone,
    required String code,
  }) async {
    await _api.post(
      '/api/otp/verify-phone',
      body: {'phone': phone, 'code': code},
    );
  }

  Future<ChatThread> createThread({
    required String token,
    required int userId,
  }) async {
    final body = await _api.post(
      '/api/chat/threads',
      token: token,
      body: {'user_id': userId},
    );
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return ChatThread.fromJson(data['thread'] as Map<String, dynamic>? ?? {});
  }

  Future<List<ChatMessage>> fetchMessages({
    required String token,
    required int threadId,
  }) async {
    final body = await _api.get(
      '/api/chat/threads/$threadId/messages',
      token: token,
    );
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final messages = data['messages'] as List? ?? const [];
    return messages
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String token,
    required int threadId,
    required String body,
  }) async {
    final response = await _api.post(
      '/api/chat/threads/$threadId/messages',
      token: token,
      body: {'body': body},
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    return ChatMessage.fromJson(data['message'] as Map<String, dynamic>? ?? {});
  }

  Stream<ChatMessage> streamMessages({
    required String token,
    required int threadId,
  }) async* {
    final request = http.Request(
      'GET',
      Uri.parse('${ApiConfig.baseUrl}/api/chat/threads/$threadId/stream'),
    );
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Authorization'] = 'Bearer $token';

    final response = await _streamClient.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Unable to connect to chat updates.',
        statusCode: response.statusCode,
      );
    }

    String? event;
    final data = StringBuffer();
    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (event == 'message' && data.isNotEmpty) {
          final decoded = jsonDecode(data.toString());
          if (decoded is Map<String, dynamic>) {
            yield ChatMessage.fromJson(decoded);
          }
        }
        event = null;
        data.clear();
        continue;
      }

      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data.write(line.substring(5).trim());
      }
    }
  }

  Future<String> askAi({
    required String token,
    required String question,
    required String finding,
    String? language,
  }) async {
    final response = await _api.post(
      '/api/chat/ai',
      token: token,
      body: {
        'question': question,
        'finding': finding,
        if (language != null) 'language': language,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    return data['answer'] as String? ?? 'Sorry, no answer generated.';
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
