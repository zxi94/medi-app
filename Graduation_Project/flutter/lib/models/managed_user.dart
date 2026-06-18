class ManagedUser {
  final int id;
  final int? profileId;
  final String name;
  final String email;
  final String role;
  final String? gender;
  final String? dob;
  final String? medicalHistory;
  final String? specialization;
  final String? medicalCertificate;
  final bool? isVerified;
  final String? verificationStatus;
  final DateTime? createdAt;

  const ManagedUser({
    required this.id,
    this.profileId,
    required this.name,
    required this.email,
    required this.role,
    this.gender,
    this.dob,
    this.medicalHistory,
    this.specialization,
    this.medicalCertificate,
    this.isVerified,
    this.verificationStatus,
    this.createdAt,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      id: _readInt(json['id']),
      profileId: _readNullableInt(json['profile_id']),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'patient',
      gender: json['gender'] as String?,
      dob: json['dob'] as String?,
      medicalHistory: json['medical_history'] as String?,
      specialization: json['specialization'] as String?,
      medicalCertificate: json['medical_certificate'] as String?,
      isVerified: json['is_verified'] as bool?,
      verificationStatus: json['verification_status'] as String?,
      createdAt: _readDate(json['created_at']),
    );
  }

  String get initials {
    final source = name.isNotEmpty ? name : email;
    final parts = source.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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
