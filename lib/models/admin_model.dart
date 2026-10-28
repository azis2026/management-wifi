class AdminModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'Super Admin', 'Admin Keuangan', 'Admin Teknisi', 'Admin Layanan'
  final String phone;
  final String? avatarUrl;
  final bool isActive;
  final String createdAt;

  const AdminModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.avatarUrl,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'avatar_url': avatarUrl,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory AdminModel.fromMap(Map<String, dynamic> map) {
    return AdminModel(
      id: (map['id'] ?? '').toString(),
      name: map['name'] as String? ?? 'Admin',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'Admin',
      phone: map['phone'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  AdminModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? avatarUrl,
    bool? isActive,
    String? createdAt,
  }) {
    return AdminModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 4 Akun Admin Default
  static List<AdminModel> get defaultAdmins => [
    AdminModel(
      id: 'admin-01',
      name: 'Admin Utama (Owner)',
      email: 'admin1@wifimanager.com',
      role: 'Super Admin',
      phone: '081234567801',
      isActive: true,
      createdAt: DateTime.now().toIso8601String(),
    ),
    AdminModel(
      id: 'admin-02',
      name: 'Admin Keuangan & Kasir',
      email: 'admin2@wifimanager.com',
      role: 'Admin Keuangan',
      phone: '081234567802',
      isActive: true,
      createdAt: DateTime.now().toIso8601String(),
    ),
    AdminModel(
      id: 'admin-03',
      name: 'Admin Lapangan & Teknisi',
      email: 'admin3@wifimanager.com',
      role: 'Admin Teknisi',
      phone: '081234567803',
      isActive: true,
      createdAt: DateTime.now().toIso8601String(),
    ),
    AdminModel(
      id: 'admin-04',
      name: 'Admin Layanan & CS',
      email: 'admin4@wifimanager.com',
      role: 'Admin Layanan',
      phone: '081234567804',
      isActive: true,
      createdAt: DateTime.now().toIso8601String(),
    ),
  ];
}
