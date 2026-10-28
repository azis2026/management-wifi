import '../utils/currency_formatter.dart';
import '../utils/billing_calculator.dart';

class PackageModel {
  final int? id;
  final String name;
  final String speed;
  final int monthlyPrice;
  final int? customDailyPrice;
  final int installationFee;
  final bool isActive;
  final String createdAt;

  PackageModel({
    this.id,
    required this.name,
    required this.speed,
    required this.monthlyPrice,
    this.customDailyPrice,
    this.installationFee = 0,
    this.isActive = true,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  /// Mengetahui apakah paket menggunakan biaya harian kustom sendiri
  bool get hasCustomDailyPrice => customDailyPrice != null && customDailyPrice! > 0;

  /// Biaya harian paket (Kustom sesuai input sendiri jika ada, atau default: bulanan ÷ 30)
  double get dailyPrice {
    if (hasCustomDailyPrice) {
      return customDailyPrice!.toDouble();
    }
    return BillingCalculator.calculateDailyFee(monthlyPrice);
  }

  /// Alias harga bulanan untuk kompatibilitas
  int get price => monthlyPrice;

  /// Label nama lengkap paket untuk dropdown & detail
  String get displayName => '$name - $speed (${CurrencyFormatter.format(monthlyPrice)})';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'speed': speed,
      'monthly_price': monthlyPrice,
      'custom_daily_price': customDailyPrice ?? 0,
      'installation_fee': installationFee,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory PackageModel.fromMap(Map<String, dynamic> map) {
    final customDaily = map['custom_daily_price'] as int?;
    return PackageModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      speed: map['speed'] as String,
      monthlyPrice: map['monthly_price'] as int,
      customDailyPrice: customDaily != null && customDaily > 0 ? customDaily : null,
      installationFee: (map['installation_fee'] as int?) ?? 0,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  PackageModel copyWith({
    int? id,
    String? name,
    String? speed,
    int? monthlyPrice,
    int? customDailyPrice,
    bool clearCustomDailyPrice = false,
    int? installationFee,
    bool? isActive,
  }) {
    return PackageModel(
      id: id ?? this.id,
      name: name ?? this.name,
      speed: speed ?? this.speed,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      customDailyPrice: clearCustomDailyPrice ? null : (customDailyPrice ?? this.customDailyPrice),
      installationFee: installationFee ?? this.installationFee,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
