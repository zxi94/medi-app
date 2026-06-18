class ChatContact {
  final int userId;
  final int profileId;
  final String role;
  final String name;
  final String email;
  final String subtitle;
  final bool? isVerified;
  final String? verificationStatus;

  const ChatContact({
    required this.userId,
    required this.profileId,
    required this.role,
    required this.name,
    required this.email,
    required this.subtitle,
    this.isVerified,
    this.verificationStatus,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      userId: _readInt(json['user_id']),
      profileId: _readInt(json['profile_id']),
      role: json['role'] as String? ?? 'patient',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      isVerified: json['is_verified'] as bool?,
      verificationStatus: json['verification_status'] as String?,
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class ChatThread {
  final int id;
  final ChatContact patient;
  final ChatContact doctor;
  final ChatMessage? latestMessage;
  final DateTime? updatedAt;

  const ChatThread({
    required this.id,
    required this.patient,
    required this.doctor,
    this.latestMessage,
    this.updatedAt,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final latestJson = json['latest_message'];
    return ChatThread(
      id: _readInt(json['id']),
      patient: ChatContact.fromJson(
        json['patient'] as Map<String, dynamic>? ?? const {},
      ),
      doctor: ChatContact.fromJson(
        json['doctor'] as Map<String, dynamic>? ?? const {},
      ),
      latestMessage: latestJson is Map<String, dynamic>
          ? ChatMessage.fromJson(latestJson)
          : null,
      updatedAt: _readDate(json['updated_at']),
    );
  }

  ChatContact otherParticipant(String currentRole) {
    return currentRole.toLowerCase() == 'doctor' ? patient : doctor;
  }
}

class ChatMessage {
  final int id;
  final int threadId;
  final int senderUserId;
  final String body;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderUserId,
    required this.body,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _readInt(json['id']),
      threadId: _readInt(json['thread_id']),
      senderUserId: _readInt(json['sender_user_id']),
      body: json['body'] as String? ?? '',
      createdAt: _readDate(json['created_at']),
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _readDate(dynamic value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}
