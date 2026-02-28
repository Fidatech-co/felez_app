class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.email,
    required this.phone,
  });

  final int id;
  final String fullName;
  final String role;
  final String email;
  final String phone;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int? ?? 0,
      fullName: json['full_name']?.toString() ?? 'کاربر سامانه',
      role: json['role']?.toString() ?? 'کاربر سامانه',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role,
      'email': email,
      'phone': phone,
    };
  }
}
