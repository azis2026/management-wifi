import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/bill_model.dart';
import '../models/customer_model.dart';
import '../utils/date_formatter.dart';
import '../services/supabase_service.dart';

class BillRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Update bills whose due date has passed into 'Terlambat'
  Future<void> updateOverdueStatus() async {
    final db = await _dbHelper.database;
    final today = DateFormatter.toIsoDateOnly(DateTime.now());

    await db.rawUpdate('''
      UPDATE ${DatabaseHelper.tableBills}
      SET status = '${BillStatus.overdue}'
      WHERE due_date < ? 
        AND status IN ('${BillStatus.unpaid}', 'Belum Bayar', '${BillStatus.partial}', 'Bayar Sebagian', '${BillStatus.unbilled}')
    ''', [today]);
  }

  Future<List<BillModel>> getBills({
    String? status,
    int? customerId,
    String? searchQuery,
    int? month,
    int? year,
    int? limit,
  }) async {
    // 1. Sinkronisasi tagihan terbaru dari Supabase jika online
    if (SupabaseService.instance.isOnline && SupabaseService.instance.client != null) {
      try {
        final List<dynamic> cloudBills = await SupabaseService.instance.client!.from('bills').select();
        if (cloudBills.isNotEmpty) {
          final db = await _dbHelper.database;
          for (final item in cloudBills) {
            await db.insert(
              DatabaseHelper.tableBills,
              {
                'id': item['id'],
                'bill_number': item['bill_number'],
                'customer_id': item['customer_id'],
                'customer_code': item['customer_code'],
                'customer_name': item['customer_name'],
                'customer_phone': item['customer_phone'] ?? '',
                'package_id': item['package_id'] ?? 1,
                'package_name': item['package_name'] ?? '',
                'period_month': item['period_month'] ?? 1,
                'period_year': item['period_year'] ?? DateTime.now().year,
                'period_start': item['period_start'] ?? '',
                'period_end': item['period_end'] ?? '',
                'amount': item['amount'] ?? 0,
                'paid_amount': item['paid_amount'] ?? 0,
                'remaining_amount': item['remaining_amount'] ?? 0,
                'installation_fee': item['installation_fee'] ?? 0,
                'subscription_fee': item['subscription_fee'] ?? 0,
                'additional_fee': item['additional_fee'] ?? 0,
                'discount': item['discount'] ?? 0,
                'is_first_bill': (item['is_first_bill'] == true || item['is_first_bill'] == 1) ? 1 : 0,
                'due_date': item['due_date'] ?? '',
                'status': item['status'] ?? 'Belum Bayar',
                'notes': item['notes'] ?? '',
                'created_at': item['created_at'] ?? DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      } catch (_) {}
    }

    await updateOverdueStatus();
    final db = await _dbHelper.database;

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (status != null && status.isNotEmpty && status != 'Semua') {
      if (status == BillStatus.overdue || status == 'Melewati Jatuh Tempo') {
        whereClauses.add('(status = ? OR status = ?)');
        whereArgs.addAll([BillStatus.overdue, 'Melewati Jatuh Tempo']);
      } else if (status == BillStatus.unpaid || status == 'Belum Dibayar') {
        whereClauses.add('(status = ? OR status = ?)');
        whereArgs.addAll([BillStatus.unpaid, 'Belum Dibayar']);
      } else {
        whereClauses.add('status = ?');
        whereArgs.add(status);
      }
    }

    if (customerId != null) {
      whereClauses.add('customer_id = ?');
      whereArgs.add(customerId);
    }

    if (month != null) {
      whereClauses.add('period_month = ?');
      whereArgs.add(month);
    }

    if (year != null) {
      whereClauses.add('period_year = ?');
      whereArgs.add(year);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(customer_name LIKE ? OR bill_number LIKE ? OR customer_code LIKE ?)');
      final q = '%${searchQuery.trim()}%';
      whereArgs.addAll([q, q, q]);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final maps = await db.query(
      DatabaseHelper.tableBills,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'due_date DESC, id DESC',
      limit: limit,
    );

    return maps.map((m) => BillModel.fromMap(m)).toList();
  }

  Future<BillModel?> getBillById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableBills,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return BillModel.fromMap(maps.first);
    }
    return null;
  }

  /// Get unpaid or partially paid bills for a specific customer
  Future<List<BillModel>> getUnpaidBillsForCustomer(int customerId) async {
    await updateOverdueStatus();
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableBills,
      where: 'customer_id = ? AND status IN (?, ?, ?, ?, ?)',
      whereArgs: [
        customerId,
        BillStatus.unpaid,
        'Belum Bayar',
        BillStatus.partial,
        BillStatus.overdue,
        'Melewati Jatuh Tempo'
      ],
      orderBy: 'due_date ASC',
    );
    return maps.map((m) => BillModel.fromMap(m)).toList();
  }

  /// Check if bill already exists for customer and month/year or period
  Future<bool> checkBillExists(int customerId, int month, int year) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM ${DatabaseHelper.tableBills}
      WHERE customer_id = ? AND period_month = ? AND period_year = ? AND status != '${BillStatus.cancelled}'
    ''', [customerId, month, year]);
    final count = (result.first['count'] as int?) ?? 0;
    return count > 0;
  }

  /// Create a single bill
  Future<int> createBill({
    required CustomerModel customer,
    required int month,
    required int year,
    required DateTime dueDate,
    int? customAmount,
    int? customPackageId,
    String? customPackageName,
    DateTime? periodStart,
    DateTime? periodEnd,
    int installationFee = 0,
    int subscriptionFee = 0,
    int additionalFee = 0,
    int discount = 0,
    bool isFirstBill = false,
    String notes = '',
    bool allowDuplicate = false,
  }) async {
    if (!allowDuplicate) {
      final exists = await checkBillExists(customer.id!, month, year);
      if (exists) {
        throw Exception('Tagihan untuk ${customer.name} pada periode ${DateFormatter.formatPeriod(month, year)} sudah pernah dibuat.');
      }
    }

    final db = await _dbHelper.database;
    final billNumber = await _dbHelper.generateBillNumber(month, year);
    final amount = customAmount ?? (subscriptionFee > 0 ? (installationFee + subscriptionFee + additionalFee - discount) : customer.monthlyFee);
    final dueDateStr = DateFormatter.toIsoDateOnly(dueDate);

    final start = periodStart ?? DateTime(year, month, 1);
    final end = periodEnd ?? start.add(const Duration(days: 30));

    final today = DateFormatter.toIsoDateOnly(DateTime.now());
    final status = dueDateStr.compareTo(today) < 0 ? BillStatus.overdue : BillStatus.unpaid;

    final bill = BillModel(
      billNumber: billNumber,
      customerId: customer.id!,
      customerCode: customer.customerCode,
      customerName: customer.name,
      customerPhone: customer.phone,
      packageId: customPackageId ?? customer.packageId,
      packageName: customPackageName ?? customer.packageName,
      periodMonth: month,
      periodYear: year,
      periodStart: DateFormatter.toIsoDateOnly(start),
      periodEnd: DateFormatter.toIsoDateOnly(end),
      amount: amount,
      paidAmount: 0,
      remainingAmount: amount,
      installationFee: installationFee,
      subscriptionFee: subscriptionFee > 0 ? subscriptionFee : customer.monthlyFee,
      additionalFee: additionalFee,
      discount: discount,
      isFirstBill: isFirstBill,
      dueDate: dueDateStr,
      status: status,
      notes: notes,
    );

    final id = await db.insert(DatabaseHelper.tableBills, bill.toMap());

    if (SupabaseService.instance.isOnline && SupabaseService.instance.client != null) {
      try {
        await SupabaseService.instance.client!.from('bills').upsert({
          'id': id,
          'bill_number': bill.billNumber,
          'customer_id': bill.customerId,
          'customer_code': bill.customerCode,
          'customer_name': bill.customerName,
          'customer_phone': bill.customerPhone,
          'package_id': bill.packageId,
          'package_name': bill.packageName,
          'period_month': bill.periodMonth,
          'period_year': bill.periodYear,
          'period_start': bill.periodStart,
          'period_end': bill.periodEnd,
          'amount': bill.amount,
          'paid_amount': bill.paidAmount,
          'remaining_amount': bill.remainingAmount,
          'installation_fee': bill.installationFee,
          'subscription_fee': bill.subscriptionFee,
          'additional_fee': bill.additionalFee,
          'discount': bill.discount,
          'is_first_bill': bill.isFirstBill,
          'due_date': bill.dueDate,
          'status': bill.status,
          'notes': bill.notes,
          'created_by_admin': SupabaseService.instance.currentAdmin.name,
        });
      } catch (e) {
        debugPrint('Error syncing bill to Supabase: $e');
      }
    }

    return id;
  }

  /// Generate recurring bills automatically for active customers every 30 days
  Future<Map<String, dynamic>> autoGenerateRecurringBills() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final custMaps = await db.query(
      DatabaseHelper.tableCustomers,
      where: 'is_active = 1',
    );
    final customers = custMaps.map((m) => CustomerModel.fromMap(m)).toList();

    int generatedCount = 0;
    int skippedCount = 0;

    for (final customer in customers) {
      // Find latest non-cancelled bill for this customer
      final latestBillMaps = await db.query(
        DatabaseHelper.tableBills,
        where: 'customer_id = ? AND status != ?',
        whereArgs: [customer.id, BillStatus.cancelled],
        orderBy: 'due_date DESC, id DESC',
        limit: 1,
      );

      DateTime nextStart;
      if (latestBillMaps.isNotEmpty) {
        final latest = BillModel.fromMap(latestBillMaps.first);
        DateTime lastEnd;
        if (latest.periodEnd.isNotEmpty) {
          lastEnd = DateFormatter.parseDate(latest.periodEnd);
        } else {
          lastEnd = DateTime(latest.periodYear, latest.periodMonth + 1, customer.dueDay.clamp(1, 28));
        }

        // If today hasn't reached the cycle renewal window (within 3 days before periodEnd or after), skip
        if (today.isBefore(lastEnd.subtract(const Duration(days: 3)))) {
          skippedCount++;
          continue;
        }

        nextStart = lastEnd.add(const Duration(days: 1));
      } else {
        nextStart = DateFormatter.parseDate(customer.startDate);
      }

      final nextEnd = nextStart.add(const Duration(days: 30));
      final nextStartStr = DateFormatter.toIsoDateOnly(nextStart);
      final nextEndStr = DateFormatter.toIsoDateOnly(nextEnd);

      // Check if bill for this period already exists
      final existsRes = await db.rawQuery('''
        SELECT COUNT(*) as count FROM ${DatabaseHelper.tableBills}
        WHERE customer_id = ? 
          AND (period_start = ? OR (period_month = ? AND period_year = ?))
          AND status != ?
      ''', [customer.id, nextStartStr, nextStart.month, nextStart.year, BillStatus.cancelled]);
      final existsCount = (existsRes.first['count'] as int?) ?? 0;
      if (existsCount > 0) {
        skippedCount++;
        continue;
      }

      final safeDueDay = customer.dueDay.clamp(1, 28);
      final dueDate = DateTime(nextStart.year, nextStart.month, safeDueDay);
      final dueDateStr = DateFormatter.toIsoDateOnly(dueDate);

      final todayStr = DateFormatter.toIsoDateOnly(today);
      final initialStatus = dueDateStr.compareTo(todayStr) < 0 ? BillStatus.overdue : BillStatus.unpaid;

      final billNumber = await _dbHelper.generateBillNumber(nextStart.month, nextStart.year);

      final recurringBill = BillModel(
        billNumber: billNumber,
        customerId: customer.id!,
        customerCode: customer.customerCode,
        customerName: customer.name,
        customerPhone: customer.phone,
        packageId: customer.packageId,
        packageName: customer.packageName,
        periodMonth: nextStart.month,
        periodYear: nextStart.year,
        periodStart: nextStartStr,
        periodEnd: nextEndStr,
        amount: customer.monthlyFee,
        paidAmount: 0,
        remainingAmount: customer.monthlyFee,
        installationFee: 0, // NO installation fee on recurring bills!
        subscriptionFee: customer.monthlyFee,
        additionalFee: 0,
        discount: 0,
        isFirstBill: false,
        dueDate: dueDateStr,
        status: initialStatus,
        notes: 'Tagihan Rutin Bulanan',
      );

      await db.insert(DatabaseHelper.tableBills, recurringBill.toMap());
      generatedCount++;
    }

    return {
      'generated': generatedCount,
      'skipped': skippedCount,
      'total_active': customers.length,
    };
  }

  /// Batch create monthly bills for all active customers manually
  Future<Map<String, int>> batchCreateMonthlyBills({
    required int month,
    required int year,
  }) async {
    final db = await _dbHelper.database;

    final customerMaps = await db.query(
      DatabaseHelper.tableCustomers,
      where: 'is_active = 1',
    );
    final customers = customerMaps.map((m) => CustomerModel.fromMap(m)).toList();

    int createdCount = 0;
    int skippedCount = 0;

    for (var cust in customers) {
      final exists = await checkBillExists(cust.id!, month, year);
      if (exists) {
        skippedCount++;
        continue;
      }

      final safeDay = cust.dueDay.clamp(1, 28);
      final dueDate = DateTime(year, month, safeDay);
      final start = DateTime(year, month, 1);
      final end = start.add(const Duration(days: 30));

      await createBill(
        customer: cust,
        month: month,
        year: year,
        dueDate: dueDate,
        periodStart: start,
        periodEnd: end,
      );
      createdCount++;
    }

    return {
      'created': createdCount,
      'skipped': skippedCount,
    };
  }

  /// Cancel bill with reason
  Future<void> cancelBill(int billId, String reason) async {
    final db = await _dbHelper.database;

    final payments = await db.query(
      DatabaseHelper.tablePayments,
      where: 'bill_id = ? AND is_cancelled = 0',
      whereArgs: [billId],
    );

    if (payments.isNotEmpty) {
      throw Exception('Tagihan tidak dapat dibatalkan karena memiliki riwayat pembayaran aktif. Batalkan pembayaran terlebih dahulu.');
    }

    await db.update(
      DatabaseHelper.tableBills,
      {
        'status': BillStatus.cancelled,
        'cancel_reason': reason,
      },
      where: 'id = ?',
      whereArgs: [billId],
    );
  }

  /// Dashboard Aggregates (Section 8)
  Future<Map<String, dynamic>> getDashboardStats() async {
    await updateOverdueStatus();
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final in3DaysStr = DateFormatter.toIsoDateOnly(now.add(const Duration(days: 3)));

    // 1. Total Customers, Active & Inactive
    final allCustRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableCustomers}',
    );
    final totalCustomers = (allCustRes.first['count'] as int?) ?? 0;

    final activeCustRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableCustomers} WHERE is_active = 1',
    );
    final activeCustomers = (activeCustRes.first['count'] as int?) ?? 0;
    final inactiveCustomers = totalCustomers - activeCustomers;

    // 2. Total Bills & Income This Month
    final monthBillsRes = await db.rawQuery('''
      SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total_amount
      FROM ${DatabaseHelper.tableBills}
      WHERE period_month = ? AND period_year = ? AND status != '${BillStatus.cancelled}'
    ''', [currentMonth, currentYear]);
    final monthBillsCount = (monthBillsRes.first['count'] as int?) ?? 0;
    final monthBillsTotal = (monthBillsRes.first['total_amount'] as int?) ?? 0;

    final incomeRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount_paid), 0) as total 
      FROM ${DatabaseHelper.tablePayments}
      WHERE is_cancelled = 0 
        AND strftime('%m', payment_date) = ? 
        AND strftime('%Y', payment_date) = ?
    ''', [currentMonth.toString().padLeft(2, '0'), currentYear.toString()]);
    final incomeThisMonth = (incomeRes.first['total'] as int?) ?? 0;

    // 3. Paid Bills This Month
    final paidBillsRes = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM ${DatabaseHelper.tableBills}
      WHERE status = '${BillStatus.paid}'
        AND period_month = ? AND period_year = ?
    ''', [currentMonth, currentYear]);
    final paidBillsThisMonth = (paidBillsRes.first['count'] as int?) ?? 0;

    // 4. Unpaid & Partial Bills
    final unpaidBillsRes = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM ${DatabaseHelper.tableBills}
      WHERE status IN ('${BillStatus.unpaid}', 'Belum Bayar', '${BillStatus.partial}', 'Bayar Sebagian', '${BillStatus.unbilled}')
    ''');
    final unpaidBillsCount = (unpaidBillsRes.first['count'] as int?) ?? 0;

    // 5. Overdue Bills Count
    final overdueRes = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM ${DatabaseHelper.tableBills}
      WHERE status IN ('${BillStatus.overdue}', 'Melewati Jatuh Tempo')
    ''');
    final overdueBillsCount = (overdueRes.first['count'] as int?) ?? 0;

    // 6. Total Arrears
    final arrearsRes = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining_amount), 0) as total 
      FROM ${DatabaseHelper.tableBills}
      WHERE status IN ('${BillStatus.unpaid}', 'Belum Bayar', '${BillStatus.partial}', 'Bayar Sebagian', '${BillStatus.overdue}', 'Melewati Jatuh Tempo', '${BillStatus.unbilled}')
    ''');
    final totalArrears = (arrearsRes.first['total'] as int?) ?? 0;

    // 7. Approaching Due Date Bills (due today up to 3 days ahead, or overdue)
    final approachingMaps = await db.query(
      DatabaseHelper.tableBills,
      where: 'status IN (?, ?, ?, ?, ?) AND due_date <= ?',
      whereArgs: [
        BillStatus.unpaid,
        'Belum Bayar',
        BillStatus.partial,
        BillStatus.overdue,
        'Melewati Jatuh Tempo',
        in3DaysStr
      ],
      orderBy: 'due_date ASC',
      limit: 10,
    );
    final approachingBills = approachingMaps.map((m) => BillModel.fromMap(m)).toList();

    // 8. Recent Customers (up to 5)
    final recentCustMaps = await db.query(
      DatabaseHelper.tableCustomers,
      orderBy: 'id DESC',
      limit: 5,
    );
    final recentCustomers = recentCustMaps.map((m) => CustomerModel.fromMap(m)).toList();

    return {
      'total_customers': totalCustomers,
      'active_customers': activeCustomers,
      'inactive_customers': inactiveCustomers,
      'month_bills_count': monthBillsCount,
      'month_bills_total': monthBillsTotal,
      'income_this_month': incomeThisMonth,
      'paid_bills_month': paidBillsThisMonth,
      'unpaid_bills_count': unpaidBillsCount,
      'overdue_bills_count': overdueBillsCount,
      'total_arrears': totalArrears,
      'approaching_bills': approachingBills,
      'recent_customers': recentCustomers,
    };
  }
}
