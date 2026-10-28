import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_manager/utils/currency_formatter.dart';
import 'package:wifi_manager/utils/date_formatter.dart';
import 'package:wifi_manager/models/bill_model.dart';
import 'package:wifi_manager/models/payment_model.dart';
import 'package:wifi_manager/models/package_model.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('WiFi Manager Currency and Date Formatters Test', () {
    test('CurrencyFormatter formats integer Rupiah correctly', () {
      expect(CurrencyFormatter.format(150000), 'Rp 150.000');
      expect(CurrencyFormatter.format(0), 'Rp 0');
      expect(CurrencyFormatter.format(2500000), 'Rp 2.500.000');
      expect(CurrencyFormatter.parse('Rp 150.000'), 150000);
      expect(CurrencyFormatter.parse('150000'), 150000);
    });

    test('DateFormatter formats readable Indonesian dates', () {
      final date = DateTime(2026, 10, 26, 14, 30);
      expect(DateFormatter.formatReadable(date), '26 Oktober 2026');
      expect(DateFormatter.formatPeriod(10, 2026), 'Oktober 2026');
      expect(DateFormatter.toIsoDateOnly(date), '2026-10-26');
    });

    test('BillModel calculations and status flags', () {
      final bill = BillModel(
        billNumber: 'INV-202610-0001',
        customerId: 1,
        customerCode: 'CUST-0001',
        customerName: 'Ahmad Santoso',
        packageId: 1,
        packageName: 'Paket Standar 20 Mbps',
        periodMonth: 10,
        periodYear: 2026,
        amount: 150000,
        paidAmount: 50000,
        remainingAmount: 100000,
        dueDate: '2026-10-10',
        status: BillStatus.partial,
      );

      expect(bill.remainingAmount, 100000);
      expect(bill.isPartial, true);
      expect(bill.isPaid, false);

      final paidBill = bill.copyWith(
        paidAmount: 150000,
        remainingAmount: 0,
        status: BillStatus.paid,
      );

      expect(paidBill.remainingAmount, 0);
      expect(paidBill.isPaid, true);
    });

    test('PaymentModel toMap and fromMap integrity', () {
      final payment = PaymentModel(
        receiptNumber: 'KW-20261026-0001',
        billId: 1,
        billNumber: 'INV-202610-0001',
        customerId: 1,
        customerCode: 'CUST-0001',
        customerName: 'Ahmad Santoso',
        paymentDate: '2026-10-26T10:00:00.000',
        amountPaid: 150000,
        paymentMethod: PaymentMethod.cash,
        notes: 'Lunas tunai',
      );

      final map = payment.toMap();
      final restored = PaymentModel.fromMap(map);

      expect(restored.receiptNumber, 'KW-20261026-0001');
      expect(restored.amountPaid, 150000);
      expect(restored.paymentMethod, PaymentMethod.cash);
      expect(restored.isCancelled, false);
    });

    test('PackageModel auto vs custom daily price calculation', () {
      // 1. Paket dengan hitungan otomatis (bulanan ÷ 30)
      final autoPkg = PackageModel(
        name: 'Paket Hemat',
        speed: '10 Mbps',
        monthlyPrice: 150000,
      );
      expect(autoPkg.hasCustomDailyPrice, false);
      expect(autoPkg.dailyPrice, 5000.0);

      // 2. Paket dengan custom daily price kustom sendiri
      final customPkg = PackageModel(
        name: 'Paket Hajatan 3 Hari',
        speed: '30 Mbps',
        monthlyPrice: 150000,
        customDailyPrice: 15000,
      );
      expect(customPkg.hasCustomDailyPrice, true);
      expect(customPkg.dailyPrice, 15000.0);

      // 3. toMap dan fromMap integrity
      final map = customPkg.toMap();
      expect(map['custom_daily_price'], 15000);
      final restored = PackageModel.fromMap(map);
      expect(restored.customDailyPrice, 15000);
      expect(restored.dailyPrice, 15000.0);
    });
  });
}
