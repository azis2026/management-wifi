import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../models/payment_model.dart';
import '../../models/bill_model.dart';
import '../../models/business_profile_model.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/bill_repository.dart';
import '../../utils/pdf_receipt_generator.dart';
import '../../utils/app_theme.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  final PaymentModel payment;
  final BillModel? bill;

  const ReceiptPreviewScreen({
    super.key,
    required this.payment,
    this.bill,
  });

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  final SettingsRepository _settingsRepo = SettingsRepository();
  final BillRepository _billRepo = BillRepository();

  BillModel? _bill;
  BusinessProfileModel? _business;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final business = await _settingsRepo.getBusinessProfile();
    BillModel? bill = widget.bill;
    if (bill == null) {
      bill = await _billRepo.getBillById(widget.payment.billId);
    }

    if (mounted) {
      setState(() {
        _business = business;
        _bill = bill;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bukti Pembayaran ${widget.payment.receiptNumber}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bill == null || _business == null
              ? const Center(
                  child: Text('Data tagihan atau profil usaha tidak ditemukan.'),
                )
              : PdfPreview(
                  build: (format) => PdfReceiptGenerator.generateReceiptPdf(
                    payment: widget.payment,
                    bill: _bill!,
                    business: _business!,
                  ),
                  initialPageFormat: PdfPageFormat.a5,
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  pdfFileName: 'Kuitansi_${widget.payment.receiptNumber}.pdf',
                  actionBarTheme: const PdfActionBarTheme(
                    backgroundColor: AppTheme.navyPrimary,
                    iconColor: Colors.white,
                  ),
                  loadingWidget: const Center(
                    child: CircularProgressIndicator(color: AppTheme.navyPrimary),
                  ),
                ),
    );
  }
}
