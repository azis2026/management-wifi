import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/customer_model.dart';
import '../models/bill_model.dart';
import '../models/payment_model.dart';
import '../utils/date_formatter.dart';
import '../services/supabase_service.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<CustomerModel>> getCustomers({
    bool? activeOnly,
    String? searchQuery,
    String? searchType, // 'all', 'id', 'name'
    int? packageId,
    String? paymentStatusFilter, // 'Semua', 'Lunas', 'Menunggak', 'Terlambat'
  }) async {
    // 1. Jika online, tarik data pelanggan terbaru dari Supabase Cloud agar multi-admin sinkron
    if (SupabaseService.instance.isOnline && SupabaseService.instance.client != null) {
      try {
        final List<dynamic> cloudCusts = await SupabaseService.instance.client!.from('customers').select();
        if (cloudCusts.isNotEmpty) {
          final db = await _dbHelper.database;
          for (final item in cloudCusts) {
            await db.insert(
              DatabaseHelper.tableCustomers,
              {
                'id': item['id'],
                'customer_code': item['customer_code'],
                'name': item['name'],
                'phone': item['phone'],
                'address': item['address'],
                'package_id': item['package_id'] ?? 1,
                'package_name': item['package_name'] ?? '',
                'package_speed': item['package_speed'] ?? '',
                'monthly_fee': item['monthly_fee'] ?? 0,
                'install_date': item['install_date'] ?? '',
                'start_date': item['start_date'] ?? item['install_date'] ?? '',
                'installation_fee': item['installation_fee'] ?? 0,
                'due_day': item['due_day'] ?? 10,
                'is_active': (item['is_active'] == true || item['is_active'] == 1) ? 1 : 0,
                'notes': item['notes'] ?? '',
                'ktp_image_path': item['ktp_image_path'],
                'created_at': item['created_at'] ?? DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      } catch (_) {}
    }

    final db = await _dbHelper.database;

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (activeOnly == true) {
      whereClauses.add('c.is_active = 1');
    } else if (activeOnly == false) {
      whereClauses.add('c.is_active = 0');
    }

    if (packageId != null && packageId > 0) {
      whereClauses.add('c.package_id = ?');
      whereArgs.add(packageId);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      if (searchType == 'id') {
        whereClauses.add('c.customer_code LIKE ?');
        whereArgs.add(q);
      } else if (searchType == 'name') {
        whereClauses.add('c.name LIKE ?');
        whereArgs.add(q);
      } else {
        whereClauses.add('(c.customer_code LIKE ? OR c.name LIKE ? OR c.phone LIKE ? OR c.address LIKE ?)');
        whereArgs.addAll([q, q, q, q]);
      }
    }

    final where = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT c.*,
        COALESCE(
          (SELECT SUM(b.remaining_amount) FROM ${DatabaseHelper.tableBills} b
           WHERE b.customer_id = c.id
             AND b.status IN ('Belum Bayar', 'Bayar Sebagian', 'Melewati Jatuh Tempo', 'Terlambat', 'Belum Ditagih')
          ), 0
        ) as total_arrears,
        (SELECT COUNT(*) FROM ${DatabaseHelper.tableBills} b
         WHERE b.customer_id = c.id
           AND b.status IN ('Terlambat', 'Melewati Jatuh Tempo')
        ) as overdue_bills_count
      FROM ${DatabaseHelper.tableCustomers} c
      $where
      ORDER BY c.name ASC
    ''';

    final maps = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);
    var list = maps.map((m) => CustomerModel.fromMap(m)).toList();

    // In-memory filter for paymentStatus if specified
    if (paymentStatusFilter != null && paymentStatusFilter.isNotEmpty && paymentStatusFilter != 'Semua') {
      if (paymentStatusFilter == 'Lunas') {
        list = list.where((c) => c.totalArrears == 0).toList();
      } else if (paymentStatusFilter == 'Menunggak' || paymentStatusFilter == 'Belum Bayar') {
        list = list.where((c) => c.totalArrears > 0).toList();
      } else if (paymentStatusFilter == 'Terlambat') {
        // filter by overdue
        final matchingIds = maps
            .where((m) => ((m['overdue_bills_count'] as int?) ?? 0) > 0)
            .map((m) => m['id'] as int)
            .toSet();
        list = list.where((c) => matchingIds.contains(c.id)).toList();
      }
    }

    return list;
  }

  Future<CustomerModel?> getCustomerById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT c.*,
        COALESCE(
          (SELECT SUM(b.remaining_amount) FROM ${DatabaseHelper.tableBills} b
           WHERE b.customer_id = c.id
             AND b.status IN ('Belum Bayar', 'Bayar Sebagian', 'Melewati Jatuh Tempo', 'Terlambat', 'Belum Ditagih')
          ), 0
        ) as total_arrears
      FROM ${DatabaseHelper.tableCustomers} c
      WHERE c.id = ?
    ''', [id]);
    if (maps.isNotEmpty) return CustomerModel.fromMap(maps.first);
    return null;
  }

  Future<bool> isCustomerCodeExists(String customerCode, {int? excludeId}) async {
    final db = await _dbHelper.database;
    final where = excludeId != null
        ? 'customer_code = ? AND id != ?'
        : 'customer_code = ?';
    final args = excludeId != null ? [customerCode, excludeId] : [customerCode];
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableCustomers} WHERE $where',
      args,
    );
    final count = (res.first['count'] as int?) ?? 0;
    return count > 0;
  }

  /// Create customer only
  Future<int> createCustomer(CustomerModel customer) async {
    final db = await _dbHelper.database;
    final code = customer.customerCode.trim().isNotEmpty
        ? customer.customerCode.trim()
        : await _dbHelper.generateCustomerCode();

    final exists = await isCustomerCodeExists(code);
    if (exists) {
      throw Exception('Kode / ID Pelanggan "$code" sudah terdaftar. Gunakan kode lain.');
    }

    final customerWithCode = customer.copyWith(customerCode: code);
    return await db.insert(DatabaseHelper.tableCustomers, customerWithCode.toMap());
  }

  /// Create customer with first bill and optional immediate payment in a single atomic transaction
  Future<Map<String, dynamic>> createCustomerWithFirstBill({
    required CustomerModel customer,
    required int firstBillTotal,
    required int installationFee,
    required int subscriptionFee,
    int additionalFee = 0,
    int discount = 0,
    required DateTime periodStart,
    required DateTime periodEnd,
    required DateTime dueDate,
    int initialPaidAmount = 0,
    String paymentMethod = 'Tunai',
    String adminNotes = '',
  }) async {
    final db = await _dbHelper.database;

    final code = customer.customerCode.trim().isNotEmpty
        ? customer.customerCode.trim()
        : await _dbHelper.generateCustomerCode();

    final exists = await isCustomerCodeExists(code);
    if (exists) {
      throw Exception('Kode / ID Pelanggan "$code" sudah terdaftar. Gunakan kode lain.');
    }

    int customerId = 0;
    int billId = 0;
    PaymentModel? payment;
    String billNumber = '';
    String dueDateStr = '';
    String periodStartStr = '';
    String periodEndStr = '';
    String billStatus = BillStatus.unpaid;

    await db.transaction((txn) async {
      // 1. Insert customer
      final customerData = customer.copyWith(
        customerCode: code,
        installationFee: installationFee,
      ).toMap();
      customerId = await txn.insert(DatabaseHelper.tableCustomers, customerData);

      // 2. Generate First Bill Number
      final now = DateTime.now();
      final prefix = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}';
      final countRes = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableBills} WHERE bill_number LIKE ?',
        ['$prefix%'],
      );
      final count = (countRes.first['count'] as int?) ?? 0;
      billNumber = '$prefix-${(count + 1).toString().padLeft(4, '0')}';

      dueDateStr = DateFormatter.toIsoDateOnly(dueDate);
      periodStartStr = DateFormatter.toIsoDateOnly(periodStart);
      periodEndStr = DateFormatter.toIsoDateOnly(periodEnd);

      if (initialPaidAmount >= firstBillTotal && firstBillTotal > 0) {
        billStatus = BillStatus.paid;
      } else if (initialPaidAmount > 0) {
        billStatus = BillStatus.partial;
      }

      final billMap = {
        'bill_number': billNumber,
        'customer_id': customerId,
        'customer_code': code,
        'customer_name': customer.name,
        'customer_phone': customer.phone,
        'package_id': customer.packageId,
        'package_name': customer.packageName,
        'period_month': periodStart.month,
        'period_year': periodStart.year,
        'period_start': periodStartStr,
        'period_end': periodEndStr,
        'amount': firstBillTotal,
        'paid_amount': initialPaidAmount,
        'remaining_amount': (firstBillTotal - initialPaidAmount).clamp(0, firstBillTotal),
        'installation_fee': installationFee,
        'subscription_fee': subscriptionFee,
        'additional_fee': additionalFee,
        'discount': discount,
        'is_first_bill': 1,
        'due_date': dueDateStr,
        'status': billStatus,
        'notes': adminNotes.isNotEmpty ? adminNotes : 'Tagihan Pertama (Registrasi Baru)',
        'cancel_reason': '',
        'created_at': DateTime.now().toIso8601String(),
      };
      billId = await txn.insert(DatabaseHelper.tableBills, billMap);

      // 3. Record Payment if initial payment received
      if (initialPaidAmount > 0) {
        final y = now.year.toString().padLeft(4, '0');
        final m = now.month.toString().padLeft(2, '0');
        final d = now.day.toString().padLeft(2, '0');
        final kwPrefix = 'KW-$y$m$d';
        final payCountRes = await txn.rawQuery(
          'SELECT COUNT(*) as count FROM ${DatabaseHelper.tablePayments} WHERE receipt_number LIKE ?',
          ['$kwPrefix%'],
        );
        final payCount = (payCountRes.first['count'] as int?) ?? 0;
        final receiptNumber = '$kwPrefix-${(payCount + 1).toString().padLeft(4, '0')}';

        payment = PaymentModel(
          receiptNumber: receiptNumber,
          billId: billId,
          billNumber: billNumber,
          customerId: customerId,
          customerCode: code,
          customerName: customer.name,
          paymentDate: DateTime.now().toIso8601String(),
          amountPaid: initialPaidAmount,
          paymentMethod: paymentMethod,
          notes: 'Pembayaran tagihan pertama saat pendaftaran',
        );
        await txn.insert(DatabaseHelper.tablePayments, payment!.toMap());
      }
    });

    // Realtime Cloud Sync ke Supabase jika online
    if (SupabaseService.instance.isOnline && SupabaseService.instance.client != null) {
      try {
        await SupabaseService.instance.client!.from('customers').upsert({
          'id': customerId,
          'customer_code': code,
          'name': customer.name,
          'phone': customer.phone,
          'address': customer.address,
          'package_id': customer.packageId,
          'package_name': customer.packageName,
          'package_speed': customer.packageSpeed,
          'monthly_fee': customer.monthlyFee,
          'install_date': customer.installDate,
          'start_date': customer.startDate,
          'installation_fee': installationFee,
          'due_day': customer.dueDay,
          'is_active': customer.isActive,
          'notes': customer.notes,
          'ktp_image_path': customer.ktpImagePath,
          'created_by_admin': SupabaseService.instance.currentAdmin.name,
        });

        await SupabaseService.instance.client!.from('bills').upsert({
          'id': billId,
          'bill_number': billNumber,
          'customer_id': customerId,
          'customer_code': code,
          'customer_name': customer.name,
          'customer_phone': customer.phone,
          'package_id': customer.packageId,
          'package_name': customer.packageName,
          'period_month': periodStart.month,
          'period_year': periodStart.year,
          'period_start': periodStartStr,
          'period_end': periodEndStr,
          'amount': firstBillTotal,
          'paid_amount': initialPaidAmount,
          'remaining_amount': (firstBillTotal - initialPaidAmount).clamp(0, firstBillTotal),
          'installation_fee': installationFee,
          'subscription_fee': subscriptionFee,
          'additional_fee': additionalFee,
          'discount': discount,
          'is_first_bill': true,
          'due_date': dueDateStr,
          'status': billStatus,
          'notes': adminNotes.isNotEmpty ? adminNotes : 'Tagihan Pertama (Registrasi Baru)',
          'created_by_admin': SupabaseService.instance.currentAdmin.name,
        });

        final p = payment;
        if (p != null) {
          await SupabaseService.instance.client!.from('payments').upsert({
            'receipt_number': p.receiptNumber,
            'bill_id': p.billId,
            'bill_number': p.billNumber,
            'customer_id': p.customerId,
            'customer_code': p.customerCode,
            'customer_name': p.customerName,
            'payment_date': p.paymentDate,
            'amount_paid': p.amountPaid,
            'payment_method': p.paymentMethod,
            'notes': p.notes,
            'received_by_admin': SupabaseService.instance.currentAdmin.name,
          });
        }
      } catch (e) {
        debugPrint('Error syncing new customer to Supabase: $e');
      }
    }

    return {
      'customer_id': customerId,
      'bill_id': billId,
      'payment': payment,
    };
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    final db = await _dbHelper.database;

    if (customer.customerCode.trim().isNotEmpty) {
      final exists = await isCustomerCodeExists(customer.customerCode.trim(), excludeId: customer.id);
      if (exists) {
        throw Exception('Kode / ID Pelanggan "${customer.customerCode}" sudah digunakan pelanggan lain.');
      }
    }

    await db.transaction((txn) async {
      await txn.update(
        DatabaseHelper.tableCustomers,
        customer.toMap(),
        where: 'id = ?',
        whereArgs: [customer.id],
      );

      // Sinkronkan nama pelanggan & customer_code di riwayat bills & payments
      await txn.update(
        DatabaseHelper.tableBills,
        {
          'customer_name': customer.name,
          'customer_code': customer.customerCode,
          'customer_phone': customer.phone,
        },
        where: 'customer_id = ?',
        whereArgs: [customer.id],
      );

      await txn.update(
        DatabaseHelper.tablePayments,
        {
          'customer_name': customer.name,
          'customer_code': customer.customerCode,
        },
        where: 'customer_id = ?',
        whereArgs: [customer.id],
      );
    });

    // Realtime Cloud Sync ke Supabase
    if (SupabaseService.instance.isOnline && SupabaseService.instance.client != null && customer.id != null) {
      try {
        await SupabaseService.instance.client!.from('customers').update({
          'customer_code': customer.customerCode,
          'name': customer.name,
          'phone': customer.phone,
          'address': customer.address,
          'package_id': customer.packageId,
          'package_name': customer.packageName,
          'package_speed': customer.packageSpeed,
          'monthly_fee': customer.monthlyFee,
          'install_date': customer.installDate,
          'start_date': customer.startDate,
          'installation_fee': customer.installationFee,
          'due_day': customer.dueDay,
          'is_active': customer.isActive,
          'notes': customer.notes,
          'ktp_image_path': customer.ktpImagePath,
        }).eq('id', customer.id!);
      } catch (_) {}
    }
  }

  Future<void> toggleCustomerStatus(int id, bool isActive) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableCustomers,
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    // Realtime Cloud Sync ke Supabase
    if (SupabaseService.instance.isOnline && SupabaseService.instance.client != null) {
      try {
        await SupabaseService.instance.client!.from('customers').update({
          'is_active': isActive,
        }).eq('id', id);
      } catch (_) {}
    }
  }

  Future<void> deleteCustomerHistory(int customerId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        DatabaseHelper.tablePayments,
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      await txn.delete(
        DatabaseHelper.tableBills,
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
    });
  }

  Future<void> deleteCustomer(int customerId) async {
    await deleteCustomerHistory(customerId);
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableCustomers,
      where: 'id = ?',
      whereArgs: [customerId],
    );

    // Realtime Cloud Sync ke Supabase
    if (SupabaseService.instance.isOnline && SupabaseService.instance.client != null) {
      try {
        await SupabaseService.instance.client!.from('customers').delete().eq('id', customerId);
      } catch (_) {}
    }
  }

  Future<int> getTotalCustomers({bool? activeOnly}) async {
    final db = await _dbHelper.database;
    final where = activeOnly == null ? null : 'is_active = ${activeOnly ? 1 : 0}';
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableCustomers}${where != null ? ' WHERE $where' : ''}',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Ambil ringkasan lengkap data pelanggan untuk keperluan Excel Export
  Future<Map<String, dynamic>> getCustomerComprehensiveDetails(int customerId) async {
    final db = await _dbHelper.database;

    // 1. First bill
    final firstBillMaps = await db.query(
      DatabaseHelper.tableBills,
      where: 'customer_id = ? AND status != ?',
      whereArgs: [customerId, BillStatus.cancelled],
      orderBy: 'id ASC',
      limit: 1,
    );
    final firstBill = firstBillMaps.isNotEmpty ? BillModel.fromMap(firstBillMaps.first) : null;

    // 2. All bills totals
    final billsTotalRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(amount), 0) as total_bills,
        COALESCE(SUM(paid_amount), 0) as total_paid,
        COALESCE(SUM(remaining_amount), 0) as total_remaining
      FROM ${DatabaseHelper.tableBills}
      WHERE customer_id = ? AND status != ?
    ''', [customerId, BillStatus.cancelled]);
    final totalBills = (billsTotalRes.first['total_bills'] as int?) ?? 0;
    final totalPaidBills = (billsTotalRes.first['total_paid'] as int?) ?? 0;
    final totalRemaining = (billsTotalRes.first['total_remaining'] as int?) ?? 0;

    // 3. Last payment
    final lastPaymentMaps = await db.query(
      DatabaseHelper.tablePayments,
      where: 'customer_id = ? AND is_cancelled = 0',
      whereArgs: [customerId],
      orderBy: 'payment_date DESC, id DESC',
      limit: 1,
    );
    final lastPayment = lastPaymentMaps.isNotEmpty ? PaymentModel.fromMap(lastPaymentMaps.first) : null;

    // 4. Latest active bill for next due date and period end
    final latestBillMaps = await db.query(
      DatabaseHelper.tableBills,
      where: 'customer_id = ? AND status != ?',
      whereArgs: [customerId, BillStatus.cancelled],
      orderBy: 'due_date DESC, id DESC',
      limit: 1,
    );
    final latestBill = latestBillMaps.isNotEmpty ? BillModel.fromMap(latestBillMaps.first) : null;

    return {
      'first_bill': firstBill,
      'total_bills': totalBills,
      'total_paid': totalPaidBills,
      'total_remaining': totalRemaining,
      'last_payment': lastPayment,
      'latest_bill': latestBill,
    };
  }
}
