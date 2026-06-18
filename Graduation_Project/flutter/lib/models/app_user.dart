class AppUser {
  final int id;
  final int? profileId;
  final String name;
  final String email;
  final bool isAdmin;
  final String role;
  final String? phone;
  final String? gender;
  final String? dob;
  final String? medicalHistory;
  final String? specialization;
  final String? medicalCertificate;
  final bool? isVerified;
  final String? verificationStatus;

  const AppUser({
    required this.id,
    this.profileId,
    required this.name,
    required this.email,
    required this.isAdmin,
    required this.role,
    this.phone,
    this.gender,
    this.dob,
    this.medicalHistory,
    this.specialization,
    this.medicalCertificate,
    this.isVerified,
    this.verificationStatus,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    int readInt(String key, {int fallback = 0}) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    int? readNullableInt(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return AppUser(
      id: readInt('id'),
      profileId: readNullableInt('profile_id'),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      isAdmin: json['isAdmin'] == true ||
          json['is_admin'] == true ||
          (json['role'] as String?)?.toLowerCase() == 'admin',
      role: json['role'] as String? ?? 'patient',
      phone: json['phone'] as String?,
      gender: json['gender'] as String?,
      dob: json['dob'] as String?,
      medicalHistory: json['medical_history'] as String?,
      specialization: json['specialization'] as String?,
      medicalCertificate: json['medical_certificate'] as String?,
      isVerified: json['is_verified'] as bool?,
      verificationStatus: json['verification_status'] as String?,
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return email.isNotEmpty ? email[0].toUpperCase() : '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
