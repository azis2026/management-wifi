import '../database/database_helper.dart';
import '../models/payment_model.dart';
import '../models/bill_model.dart';
import '../utils/date_formatter.dart';
import '../services/supabase_service.dart';

class PaymentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Record payment inside a database transaction
  Future<PaymentModel> recordPayment({
    required BillModel bill,
    required int amountPaid,
    required String paymentMethod,
    String notes = '',
  }) async {
    if (amountPaid <= 0) {
      throw Exception('Nominal pembayaran harus lebih dari Rp0.');
    }

    if (amountPaid > bill.remainingAmount) {
      throw Exception('Nominal pembayaran melebihi sisa tagihan.');
    }

    final db = await _dbHelper.database;
    final receiptNumber = await _dbHelper.generateReceiptNumber();
    final paymentDate = DateTime.now().toIso8601String();

    final payment = PaymentModel(
      receiptNumber: receiptNumber,
      billId: bill.id!,
      billNumber: bill.billNumber,
      customerId: bill.customerId,
      customerCode: bill.customerCode,
      customerName: bill.customerName,
      paymentDate: paymentDate,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      notes: notes,
    );

    await db.transaction((txn) async {
      // 1. Insert payment record
      await txn.insert(DatabaseHelper.tablePayments, payment.toMap());

      // 2. Fetch fresh bill data inside transaction
      final billMaps = await txn.query(
        DatabaseHelper.tableBills,
        where: 'id = ?',
        whereArgs: [bill.id],
      );
      if (billMaps.isEmpty) {
        throw Exception('Tagihan tidak ditemukan.');
      }
      final currentBill = BillModel.fromMap(billMaps.first);

      final newPaidAmount = currentBill.paidAmount + amountPaid;
      final newRemainingAmount = currentBill.amount - newPaidAmount;

      String newStatus;
      if (newRemainingAmount <= 0) {
        newStatus = BillStatus.paid;
      } else {
        newStatus = BillStatus.partial;
      }

      // 3. Update bill
      await txn.update(
        DatabaseHelper.tableBills,
        {
          'paid_amount': newPaidAmount,
          'remaining_amount': newRemainingAmount.clamp(0, currentBill.amount),
          'status': newStatus,
        },
        where: 'id = ?',
        whereArgs: [bill.id],
      );
    });

    // Realtime Cloud Sync ke Supabase jika sedang online
    if (SupabaseService.instance.isOnline && SupabaseService.instance.client != null) {
      try {
        SupabaseService.instance.client!.from('payments').upsert({
          'receipt_number': payment.receiptNumber,
          'bill_id': payment.billId,
          'bill_number': payment.billNumber,
          'customer_id': payment.customerId,
          'customer_code': payment.customerCode,
          'customer_name': payment.customerName,
          'payment_date': payment.paymentDate,
          'amount_paid': payment.amountPaid,
          'payment_method': payment.paymentMethod,
          'notes': payment.notes,
          'received_by_admin': SupabaseService.instance.currentAdmin.name,
        });
        SupabaseService.instance.client!.from('bills').update({
          'paid_amount': bill.paidAmount + amountPaid,
          'remaining_amount': (bill.amount - (bill.paidAmount + amountPaid)).clamp(0, bill.amount),
          'status': (bill.amount - (bill.paidAmount + amountPaid)) <= 0 ? BillStatus.paid : BillStatus.partial,
        }).eq('bill_number', bill.billNumber);
      } catch (e) {
        // Abaikan error jaringan offline
      }
    }

    return payment;
  }

  /// Cancel payment with reason and rollback bill amounts
  Future<void> cancelPayment(int paymentId, String reason) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Fetch payment
      final paymentMaps = await txn.query(
        DatabaseHelper.tablePayments,
        where: 'id = ?',
        whereArgs: [paymentId],
      );
      if (paymentMaps.isEmpty) {
        throw Exception('Transaksi pembayaran tidak ditemukan.');
      }
      final payment = PaymentModel.fromMap(paymentMaps.first);
      if (payment.isCancelled) {
        throw Exception('Transaksi ini sudah dibatalkan sebelumnya.');
      }

      // 2. Mark payment cancelled
      await txn.update(
        DatabaseHelper.tablePayments,
        {
          'is_cancelled': 1,
          'cancel_reason': reason,
        },
        where: 'id = ?',
        whereArgs: [paymentId],
      );

      // 3. Rollback bill amount
      final billMaps = await txn.query(
        DatabaseHelper.tableBills,
        where: 'id = ?',
        whereArgs: [payment.billId],
      );
      if (billMaps.isNotEmpty) {
        final bill = BillModel.fromMap(billMaps.first);
        final newPaid = (bill.paidAmount - payment.amountPaid).clamp(0, bill.amount);
        final newRemaining = (bill.amount - newPaid).clamp(0, bill.amount);

        String newStatus;
        if (newRemaining <= 0) {
          newStatus = BillStatus.paid;
        } else if (newPaid > 0) {
          newStatus = BillStatus.partial;
        } else {
          final today = DateFormatter.toIsoDateOnly(DateTime.now());
          newStatus = bill.dueDate.compareTo(today) < 0 ? BillStatus.overdue : BillStatus.unpaid;
        }

        await txn.update(
          DatabaseHelper.tableBills,
          {
            'paid_amount': newPaid,
            'remaining_amount': newRemaining,
            'status': newStatus,
          },
          where: 'id = ?',
          whereArgs: [bill.id],
        );
      }
    });
  }

  /// Get payments list with filters
  Future<List<PaymentModel>> getPayments({
    int? customerId,
    int? billId,
    String? searchQuery,
    String? paymentMethod,
    bool? onlyActive,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final db = await _dbHelper.database;
    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (customerId != null) {
      whereClauses.add('customer_id = ?');
      whereArgs.add(customerId);
    }

    if (billId != null) {
      whereClauses.add('bill_id = ?');
      whereArgs.add(billId);
    }

    if (paymentMethod != null && paymentMethod.isNotEmpty && paymentMethod != 'Semua') {
      whereClauses.add('payment_method = ?');
      whereArgs.add(paymentMethod);
    }

    if (onlyActive == true) {
      whereClauses.add('is_cancelled = 0');
    }

    if (startDate != null) {
      whereClauses.add('payment_date >= ?');
      whereArgs.add(DateFormatter.toIsoDateOnly(startDate));
    }

    if (endDate != null) {
      final nextDay = endDate.add(const Duration(days: 1));
      whereClauses.add('payment_date < ?');
      whereArgs.add(DateFormatter.toIsoDateOnly(nextDay));
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(customer_name LIKE ? OR receipt_number LIKE ? OR bill_number LIKE ?)');
      final q = '%${searchQuery.trim()}%';
      whereArgs.addAll([q, q, q]);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final maps = await db.query(
      DatabaseHelper.tablePayments,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'payment_date DESC, id DESC',
      limit: limit,
    );

    return maps.map((m) => PaymentModel.fromMap(m)).toList();
  }

  /// Get recent transactions for home dashboard
  Future<List<PaymentModel>> getRecentPayments({int limit = 6}) async {
    return await getPayments(limit: limit);
  }

  /// Get payment by ID
  Future<PaymentModel?> getPaymentById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tablePayments,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return PaymentModel.fromMap(maps.first);
    }
    return null;
  }
}
