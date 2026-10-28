import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/business_profile_model.dart';
import '../../repositories/settings_repository.dart';
import '../../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _settingsRepo = SettingsRepository();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _businessNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _footerController;

  String? _logoPath;
  String? _signaturePath;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _settingsRepo.getBusinessProfile();
    if (mounted) {
      setState(() {
        _businessNameController = TextEditingController(text: profile.businessName);
        _phoneController = TextEditingController(text: profile.contactPhone);
        _addressController = TextEditingController(text: profile.address);
        _footerController = TextEditingController(text: profile.receiptFooter);
        _logoPath = (profile.logoPath != null && profile.logoPath!.isNotEmpty) ? profile.logoPath : null;
        _signaturePath = (profile.signaturePath != null && profile.signaturePath!.isNotEmpty) ? profile.signaturePath : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickLogo() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (files.isNotEmpty && files.first.path != null) {
        setState(() {
          _logoPath = files.first.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih logo: $e')),
        );
      }
    }
  }

  Future<void> _pickSignature() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (files.isNotEmpty && files.first.path != null) {
        setState(() {
          _signaturePath = files.first.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih tanda tangan: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final profile = BusinessProfileModel(
        businessName: _businessNameController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        receiptFooter: _footerController.text.trim(),
        logoPath: _logoPath,
        signaturePath: _signaturePath,
      );

      await _settingsRepo.saveBusinessProfile(profile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil usaha, logo, dan tanda tangan berhasil disimpan'),
            backgroundColor: AppTheme.statusSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: AppTheme.statusDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildImagePickerCard({
    required String title,
    required String subtitle,
    required String? imagePath,
    required VoidCallback onPick,
    required VoidCallback onRemove,
    required IconData icon,
  }) {
    final hasImage = imagePath != null && imagePath.isNotEmpty;
    final file = hasImage ? File(imagePath) : null;
    final fileExists = file != null && file.existsSync();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.navyPrimary, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            if (hasImage && fileExists) ...[
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                alignment: Alignment.center,
                child: Image.file(file, fit: BoxFit.contain),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: onPick,
                      icon: const Icon(Icons.photo_library, size: 16),
                      label: const Text('Ganti Gambar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Hapus',
                    onPressed: onRemove,
                  ),
                ],
              ),
            ] else ...[
              InkWell(
                onTap: onPick,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: AppTheme.navyPrimary, size: 28),
                      const SizedBox(height: 4),
                      Text('Pilih Gambar / Foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.navyPrimary)),
                      const Text('Format PNG / JPG transparan', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Profil Usaha (Tampil di Kuitansi)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Informasi ini dicetak pada bagian kepala bukti pembayaran PDF.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _businessNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Usaha WiFi *',
                        prefixIcon: Icon(Icons.business, color: AppTheme.navyPrimary),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nama usaha tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Kontak / WhatsApp Admin *',
                        prefixIcon: Icon(Icons.phone_android, color: AppTheme.navyPrimary),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nomor kontak tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Alamat Usaha',
                        prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.navyPrimary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _footerController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Kaki Kuitansi',
                        hintText: 'Contoh: Terima kasih atas pembayaran Anda.',
                        prefixIcon: Icon(Icons.notes, color: AppTheme.navyPrimary),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section Logo & TTD
                    const Text(
                      'Logo & Tanda Tangan Resmi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Logo akan tampil di bagian atas kuitansi, dan tanda tangan akan dicetak di kolom pengelola.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildImagePickerCard(
                            title: 'Logo Perusahaan',
                            subtitle: 'Tampil pada header kuitansi',
                            imagePath: _logoPath,
                            onPick: _pickLogo,
                            onRemove: () => setState(() => _logoPath = null),
                            icon: Icons.image_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildImagePickerCard(
                            title: 'Tanda Tangan (TTD)',
                            subtitle: 'Tampil di kolom admin kuitansi',
                            imagePath: _signaturePath,
                            onPick: _pickSignature,
                            onRemove: () => setState(() => _signaturePath = null),
                            icon: Icons.draw_outlined,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveProfile,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Pengaturan'),
                    ),
                    const SizedBox(height: 32),

                    // App Information
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline, color: AppTheme.navyPrimary),
                                SizedBox(width: 8),
                                Text(
                                  'Tentang WiFi Manager',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.navyPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            _buildInfoRow('Versi Aplikasi', '1.0.0 (Offline Standalone)'),
                            _buildInfoRow('Engine Database', 'SQLite Local Storage'),
                            _buildInfoRow('Koneksi Internet', 'Tidak Diperlukan (Mode Pesawat OK)'),
                            _buildInfoRow('Keamanan', 'Data Lokal Internal'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
