class BillStatus {
  static const String unbilled = 'Belum Ditagih';
  static const String unpaid = 'Belum Bayar';
  static const String paid = 'Lunas';
  static const String partial = 'Bayar Sebagian';
  static const String overdue = 'Terlambat';
  static const String cancelled = 'Dibatalkan';

  static const List<String> all = [
    unpaid,
    partial,
    paid,
    overdue,
    cancelled,
    unbilled,
  ];

  static bool isOverdueStatus(String status) {
    return status == overdue || status == 'Melewati Jatuh Tempo' || status == 'Terlambat';
  }

  static bool isUnpaidStatus(String status) {
    return status == unpaid || status == 'Belum Dibayar' || status == unbilled;
  }

  static bool isPartialStatus(String status) {
    return status == partial || status == 'Dibayar Sebagian';
  }
}

class BillModel {
  final int? id;
  final String billNumber;
  final int customerId;
  final String customerCode;
  final String customerName;
  final String customerPhone;
  final int packageId;
  final String packageName;
  final int periodMonth;
  final int periodYear;
  final String periodStart;
  final String periodEnd;
  final int amount;
  final int paidAmount;
  final int remainingAmount;
  final int installationFee;
  final int subscriptionFee;
  final int additionalFee;
  final int discount;
  final bool isFirstBill;
  final String dueDate;
  final String status;
  final String notes;
  final String cancelReason;
  final String createdAt;

  BillModel({
    this.id,
    required this.billNumber,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    this.customerPhone = '',
    required this.packageId,
    required this.packageName,
    required this.periodMonth,
    required this.periodYear,
    this.periodStart = '',
    this.periodEnd = '',
    required this.amount,
    this.paidAmount = 0,
    required this.remainingAmount,
    this.installationFee = 0,
    this.subscriptionFee = 0,
    this.additionalFee = 0,
    this.discount = 0,
    this.isFirstBill = false,
    required this.dueDate,
    this.status = BillStatus.unpaid,
    this.notes = '',
    this.cancelReason = '',
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  bool get isPaid => status == BillStatus.paid;
  bool get isOverdue => BillStatus.isOverdueStatus(status);
  bool get isCancelled => status == BillStatus.cancelled;
  bool get isPartial => BillStatus.isPartialStatus(status);
  bool get isUnpaid => BillStatus.isUnpaidStatus(status);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bill_number': billNumber,
      'customer_id': customerId,
      'customer_code': customerCode,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'package_id': packageId,
      'package_name': packageName,
      'period_month': periodMonth,
      'period_year': periodYear,
      'period_start': periodStart,
      'period_end': periodEnd,
      'amount': amount,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'installation_fee': installationFee,
      'subscription_fee': subscriptionFee,
      'additional_fee': additionalFee,
      'discount': discount,
      'is_first_bill': isFirstBill ? 1 : 0,
      'due_date': dueDate,
      'status': status,
      'notes': notes,
      'cancel_reason': cancelReason,
      'created_at': createdAt,
    };
  }

  factory BillModel.fromMap(Map<String, dynamic> map) {
    return BillModel(
      id: map['id'] as int?,
      billNumber: map['bill_number'] as String? ?? '',
      customerId: map['customer_id'] as int? ?? 0,
      customerCode: map['customer_code'] as String? ?? '',
      customerName: map['customer_name'] as String? ?? '',
      customerPhone: map['customer_phone'] as String? ?? '',
      packageId: map['package_id'] as int? ?? 0,
      packageName: map['package_name'] as String? ?? '',
      periodMonth: map['period_month'] as int? ?? 1,
      periodYear: map['period_year'] as int? ?? DateTime.now().year,
      periodStart: map['period_start'] as String? ?? '',
      periodEnd: map['period_end'] as String? ?? '',
      amount: map['amount'] as int? ?? 0,
      paidAmount: map['paid_amount'] as int? ?? 0,
      remainingAmount: map['remaining_amount'] as int? ?? 0,
      installationFee: map['installation_fee'] as int? ?? 0,
      subscriptionFee: map['subscription_fee'] as int? ?? 0,
      additionalFee: map['additional_fee'] as int? ?? 0,
      discount: map['discount'] as int? ?? 0,
      isFirstBill: (map['is_first_bill'] as int?) == 1,
      dueDate: map['due_date'] as String? ?? '',
      status: map['status'] as String? ?? BillStatus.unpaid,
      notes: map['notes'] as String? ?? '',
      cancelReason: map['cancel_reason'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  BillModel copyWith({
    int? id,
    String? billNumber,
    int? customerId,
    String? customerCode,
    String? customerName,
    String? customerPhone,
    int? packageId,
    String? packageName,
    int? periodMonth,
    int? periodYear,
    String? periodStart,
    String? periodEnd,
    int? amount,
    int? paidAmount,
    int? remainingAmount,
    int? installationFee,
    int? subscriptionFee,
    int? additionalFee,
    int? discount,
    bool? isFirstBill,
    String? dueDate,
    String? status,
    String? notes,
    String? cancelReason,
    String? createdAt,
  }) {
    return BillModel(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      customerId: customerId ?? this.customerId,
      customerCode: customerCode ?? this.customerCode,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      periodMonth: periodMonth ?? this.periodMonth,
      periodYear: periodYear ?? this.periodYear,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      installationFee: installationFee ?? this.installationFee,
      subscriptionFee: subscriptionFee ?? this.subscriptionFee,
      additionalFee: additionalFee ?? this.additionalFee,
      discount: discount ?? this.discount,
      isFirstBill: isFirstBill ?? this.isFirstBill,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
