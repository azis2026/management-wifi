class BusinessProfileModel {
  final String businessName;
  final String contactPhone;
  final String address;
  final String receiptFooter;
  final String? logoPath;
  final String? signaturePath;

  const BusinessProfileModel({
    required this.businessName,
    required this.contactPhone,
    required this.address,
    required this.receiptFooter,
    this.logoPath,
    this.signaturePath,
  });

  static const BusinessProfileModel defaults = BusinessProfileModel(
    businessName: 'WiFi Net Mandiri',
    contactPhone: '0812-3456-7890',
    address: 'Jl. Merdeka No. 10',
    receiptFooter: 'Terima kasih atas pembayaran Anda. Simpan bukti ini sebagai tanda lunas.',
    logoPath: null,
    signaturePath: null,
  );
}
