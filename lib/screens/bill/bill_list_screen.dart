import 'package:flutter/material.dart';
import '../../models/bill_model.dart';
import '../../models/business_profile_model.dart';
import '../../repositories/bill_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/whatsapp_reminder_service.dart';
import '../payment/payment_record_screen.dart';


class BillListScreen extends StatefulWidget {
  final String? initialStatusFilter;
  const BillListScreen({super.key, this.initialStatusFilter});

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  final BillRepository _repo = BillRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();
  List<BillModel> _bills = [];
  bool _isLoading = true;
  late String _filterStatus;
  int _filterMonth = DateTime.now().month;
  int _filterYear = DateTime.now().year;
  BusinessProfileModel _business = BusinessProfileModel(
    businessName: 'WiFi Net Mandiri',
    contactPhone: '0812-3456-7890',
    address: 'Jl. Merdeka No. 10',
    receiptFooter: 'Terima kasih atas pembayaran Anda.',
  );

  final List<String> _statuses = [
    'Semua',
    BillStatus.unpaid,
    BillStatus.partial,
    BillStatus.overdue,
    BillStatus.paid,
    BillStatus.unbilled,
    BillStatus.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialStatusFilter ?? 'Semua';
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await _repo.autoGenerateRecurringBills();
    final profile = await _settingsRepo.getBusinessProfile();
    final bills = await _repo.getBills(
      status: _filterStatus == 'Semua' ? null : _filterStatus,
      month: _filterMonth,
      year: _filterYear,
    );
    if (mounted) setState(() { _business = profile; _bills = bills; _isLoading = false; });
  }

  Future<void> _sendWhatsAppSingle(BillModel bill) async {
    final message = WhatsAppReminderService.generateBillMessage(
      bill: bill,
      business: _business,
    );

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.chat, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text('Kirim Tagihan ke WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                message,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      WhatsAppReminderService.copyToClipboard(message);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pesan berhasil disalin!'), backgroundColor: AppTheme.statusSuccess),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Salin'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      WhatsAppReminderService.shareToWhatsApp(
                        message: message,
                        subject: 'Tagihan WiFi ${bill.customerName}',
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Kirim ke WA', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsAppBatch() async {
    final unpaidBills = _bills.where((b) => b.remainingAmount > 0 && !b.isCancelled).toList();
    if (unpaidBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada tagihan yang belum lunas pada filter ini')),
      );
      return;
    }

    final message = WhatsAppReminderService.generateBatchSummaryMessage(
      bills: unpaidBills,
      business: _business,
    );

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups, color: AppTheme.navyPrimary, size: 26),
                const SizedBox(width: 8),
                Text('Kirim Rekap Masal (${unpaidBills.length} Tagihan)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rekap tagihan belum lunas untuk periode ${DateFormatter.monthName(_filterMonth)} $_filterYear siap dibagikan ke WhatsApp grup/kolektor.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                message,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      WhatsAppReminderService.copyToClipboard(message);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rekap masal berhasil disalin!'), backgroundColor: AppTheme.statusSuccess),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Salin Rekap'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      WhatsAppReminderService.shareToWhatsApp(
                        message: message,
                        subject: 'Rekap Tagihan WiFi Masal',
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Bagikan ke WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case BillStatus.paid: return AppTheme.statusSuccess;
      case BillStatus.partial: return AppTheme.statusWarning;
      case BillStatus.overdue: return AppTheme.statusDanger;
      case BillStatus.cancelled: return Colors.grey;
      default: return AppTheme.navyLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Daftar Tagihan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Kirim Rekap Tagihan Belum Lunas ke WhatsApp',
            onPressed: _sendWhatsAppBatch,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _filterMonth,
                    decoration: const InputDecoration(labelText: 'Bulan', isDense: true),
                    items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(
                      value: m, child: Text(DateFormatter.monthName(m), overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) { setState(() => _filterMonth = v!); _load(); },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _filterYear,
                    decoration: const InputDecoration(labelText: 'Tahun', isDense: true),
                    items: List.generate(3, (i) => DateTime.now().year - 1 + i).map((y) => DropdownMenuItem(
                      value: y, child: Text('$y'),
                    )).toList(),
                    onChanged: (v) { setState(() => _filterYear = v!); _load(); },
                  ),
                ),
              ],
            ),
          ),
          // Status chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _statuses.map((s) {
                final selected = _filterStatus == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppTheme.textPrimary)),
                    selected: selected,
                    onSelected: (_) { setState(() => _filterStatus = s); _load(); },
                    selectedColor: _filterStatus == 'Semua' ? AppTheme.navyPrimary : _statusColor(s),
                    backgroundColor: Colors.white,
                    checkmarkColor: Colors.white,
                    showCheckmark: selected,
                  ),
                );
              }).toList(),
            ),
          ),
          // Bill count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(children: [
              Text('${_bills.length} tagihan ditemukan', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ]),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _bills.isEmpty
                    ? const Center(child: Text('Tidak ada tagihan', style: TextStyle(color: AppTheme.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: _bills.length,
                          itemBuilder: (ctx, i) {
                            final b = _bills[i];
                            final canPay = b.remainingAmount > 0 && !b.isCancelled;
                            return Card(
                              child: ListTile(
                                leading: Container(
                                  width: 4,
                                  height: 60,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(b.status),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(b.customerName, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: _statusColor(b.status).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                      child: Text(b.status, style: TextStyle(fontSize: 10, color: _statusColor(b.status), fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${b.billNumber} • ${DateFormatter.formatPeriod(b.periodMonth, b.periodYear)}'),
                                    Text('Tagihan: ${CurrencyFormatter.format(b.amount)} | Sisa: ${CurrencyFormatter.format(b.remainingAmount)}', style: const TextStyle(fontSize: 11)),
                                    Text('Jatuh Tempo: ${b.dueDate}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (canPay) ...[
                                      IconButton(
                                        icon: const Icon(Icons.send, color: Color(0xFF25D366), size: 20),
                                        tooltip: 'Kirim Tagihan ke WhatsApp',
                                        onPressed: () => _sendWhatsAppSingle(b),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.toskaAccent,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          textStyle: const TextStyle(fontSize: 12),
                                        ),
                                        onPressed: () async {
                                          final res = await Navigator.push(context, MaterialPageRoute(
                                            builder: (_) => PaymentRecordScreen(preselectedBill: b),
                                          ));
                                          if (res == true) _load();
                                        },
                                        child: const Text('Bayar'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
