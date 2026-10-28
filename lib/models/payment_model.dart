class PaymentModel {
  final int? id;
  final String receiptNumber;
  final int billId;
  final String billNumber;
  final int customerId;
  final String customerCode;
  final String customerName;
  final String paymentDate;
  final int amountPaid;
  final String paymentMethod;
  final String notes;
  final bool isCancelled;
  final String cancelReason;
  final String createdAt;

  PaymentModel({
    this.id,
    required this.receiptNumber,
    required this.billId,
    required this.billNumber,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.paymentDate,
    required this.amountPaid,
    required this.paymentMethod,
    this.notes = '',
    this.isCancelled = false,
    this.cancelReason = '',
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'receipt_number': receiptNumber,
      'bill_id': billId,
      'bill_number': billNumber,
      'customer_id': customerId,
      'customer_code': customerCode,
      'customer_name': customerName,
      'payment_date': paymentDate,
      'amount_paid': amountPaid,
      'payment_method': paymentMethod,
      'notes': notes,
      'is_cancelled': isCancelled ? 1 : 0,
      'cancel_reason': cancelReason,
      'created_at': createdAt,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as int?,
      receiptNumber: map['receipt_number'] as String? ?? '',
      billId: map['bill_id'] as int? ?? 0,
      billNumber: map['bill_number'] as String? ?? '',
      customerId: map['customer_id'] as int? ?? 0,
      customerCode: map['customer_code'] as String? ?? '',
      customerName: map['customer_name'] as String? ?? '',
      paymentDate: map['payment_date'] as String? ?? '',
      amountPaid: map['amount_paid'] as int? ?? 0,
      paymentMethod: map['payment_method'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      isCancelled: (map['is_cancelled'] as int?) == 1,
      cancelReason: map['cancel_reason'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
    );
  }
}

class PaymentMethod {
  static const String cash = 'Tunai';
  static const String bankTransfer = 'Transfer Bank';
  static const String eWallet = 'E-Wallet';
  static const String other = 'Lainnya';

  static const List<String> all = [cash, bankTransfer, eWallet, other];
}
