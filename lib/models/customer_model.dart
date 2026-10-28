import '../utils/billing_calculator.dart';
import '../utils/date_formatter.dart';

class CustomerModel {
  final int? id;
  final String customerCode;
  final String name;
  final String phone;
  final String address;
  final int packageId;
  final String packageName;
  final String packageSpeed;
  final int monthlyFee;
  final String installDate;
  final String startDate; // Tanggal mulai berlangganan
  final int installationFee; // Biaya pemasangan awal
  final int dueDay;
  final bool isActive;
  final String notes;
  final String? ktpImagePath;
  final String createdAt;
  // Computed (from bills join, not stored)
  final int totalArrears;

  CustomerModel({
    this.id,
    required this.customerCode,
    required this.name,
    required this.phone,
    required this.address,
    required this.packageId,
    required this.packageName,
    this.packageSpeed = '',
    required this.monthlyFee,
    required this.installDate,
    String? startDate,
    this.installationFee = 0,
    this.dueDay = 10,
    this.isActive = true,
    this.notes = '',
    this.ktpImagePath,
    String? createdAt,
    this.totalArrears = 0,
  })  : startDate = startDate ?? installDate,
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  /// Biaya per hari (Harga paket bulanan ÷ 30)
  double get dailyFee => BillingCalculator.calculateDailyFee(monthlyFee);

  /// Total hari berlangganan dari tanggal mulai sampai hari ini
  int get totalSubscriptionDays {
    final start = DateFormatter.parseDate(startDate);
    return BillingCalculator.calculateTotalSubscriptionDays(start);
  }

  /// Tanggal berakhir periode aktif saat ini (standar 30 hari dari siklus)
  DateTime get activePeriodEndDate {
    final start = DateFormatter.parseDate(startDate);
    // Hitung siklus berjalan (setiap 30 hari)
    final now = DateTime.now();
    DateTime cycleStart = start;
    while (cycleStart.add(const Duration(days: 30)).isBefore(now)) {
      cycleStart = cycleStart.add(const Duration(days: 30));
    }
    return cycleStart.add(const Duration(days: 30));
  }

  /// Sisa hari aktif berlangganan
  int get remainingActiveDays {
    return BillingCalculator.calculateRemainingDays(activePeriodEndDate);
  }

  /// Status pembayaran ringkas
  String get paymentStatusDescription {
    if (totalArrears <= 0) return 'Lunas';
    return 'Menunggak';
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_code': customerCode,
      'name': name,
      'phone': phone,
      'address': address,
      'package_id': packageId,
      'package_name': packageName,
      'package_speed': packageSpeed,
      'monthly_fee': monthlyFee,
      'install_date': installDate,
      'start_date': startDate,
      'installation_fee': installationFee,
      'due_day': dueDay,
      'is_active': isActive ? 1 : 0,
      'notes': notes,
      'ktp_image_path': ktpImagePath,
      'created_at': createdAt,
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    final install = map['install_date'] as String? ?? '';
    final start = map['start_date'] as String?;
    return CustomerModel(
      id: map['id'] as int?,
      customerCode: map['customer_code'] as String? ?? '',
      name: map['name'] as String,
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      packageId: map['package_id'] as int? ?? 0,
      packageName: map['package_name'] as String? ?? '',
      packageSpeed: map['package_speed'] as String? ?? '',
      monthlyFee: map['monthly_fee'] as int? ?? 0,
      installDate: install,
      startDate: (start != null && start.isNotEmpty) ? start : install,
      installationFee: map['installation_fee'] as int? ?? 0,
      dueDay: map['due_day'] as int? ?? 10,
      isActive: (map['is_active'] as int?) == 1,
      notes: map['notes'] as String? ?? '',
      ktpImagePath: map['ktp_image_path'] as String?,
      createdAt: map['created_at'] as String? ?? '',
      totalArrears: map['total_arrears'] as int? ?? 0,
    );
  }

  CustomerModel copyWith({
    int? id,
    String? customerCode,
    String? name,
    String? phone,
    String? address,
    int? packageId,
    String? packageName,
    String? packageSpeed,
    int? monthlyFee,
    String? installDate,
    String? startDate,
    int? installationFee,
    int? dueDay,
    bool? isActive,
    String? notes,
    String? ktpImagePath,
    int? totalArrears,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      customerCode: customerCode ?? this.customerCode,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      packageSpeed: packageSpeed ?? this.packageSpeed,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      installDate: installDate ?? this.installDate,
      startDate: startDate ?? this.startDate,
      installationFee: installationFee ?? this.installationFee,
      dueDay: dueDay ?? this.dueDay,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      ktpImagePath: ktpImagePath ?? this.ktpImagePath,
      createdAt: createdAt,
      totalArrears: totalArrears ?? this.totalArrears,
    );
  }
}
