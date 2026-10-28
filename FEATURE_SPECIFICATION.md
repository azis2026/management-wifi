# SPESIFIKASI FITUR APLIKASI WIFI MANAGEMENT (ISP / RT-RW NET)
> **Framework-Agnostic Feature Blueprint**
> Berkas ini murni mendefinisikan kebutuhan fungsional, entitas data, dan aturan bisnis (*business logic*) tanpa terikat pada framework/bahasa pemrograman tertentu. Dapat diimplementasikan menggunakan stack apa pun (React, Vue, Next.js, Flutter, Kotlin, Swift, Laravel, NestJS, Go, Python, dll.).

---

## 1. MODUL OTENTIKASI & MULTI-ADMIN (ROLE-BASED ACCESS CONTROL)

### Kebutuhan Fungsional:
* **Gerbang Autentikasi (Auth Guard / Middleware)**: Aplikasi wajib meminta login sebelum mengakses dashboard dan data pelanggan.
* **4 Peran Admin dengan Hak Akses Berbeda**:
  1. **Super Admin (Owner)**: Hak akses penuh ke seluruh modul, pengaturan master paket, pengaturan bisnis, manajemen akun admin lain, dan ekspor data.
  2. **Admin Keuangan (Kasir)**: Akses ke modul pembayaran, pencatatan transaksi, cetak kuitansi, dan rekapitulasi kas masuk harian.
  3. **Admin Teknisi (Lapangan)**: Akses pendaftaran pelanggan baru, dokumentasi foto KTP pelanggan, aktivasi/pergantian paket, dan pengecekan lokasi pelanggan.
  4. **Admin Layanan (Customer Service & Penagihan)**: Akses pemantauan jatuh tempo, pengiriman notifikasi pengingat via WhatsApp/pesan, dan pelayanan keluhan.
* **Fitur Sesi & Ingat Saya (Session Persistence)**: Opsi token/sesi tersimpan di perangkat lokal atau otomatis meminta login ulang saat aplikasi ditutup.
* **Audit Trail (Pencatatan Jejak Aktivitas)**: Setiap penambahan pelanggan, pembuatan tagihan, dan penerimaan pembayaran wajib mencatat identitas admin yang memprosesnya (`admin_id` & `admin_name`).

---

## 2. MODUL MANAJEMEN PELANGGAN (CUSTOMER MANAGEMENT)

### Kebutuhan Fungsional:
* **Identitas Pelanggan**:
  * Kode/ID Pelanggan (dapat di-generate otomatis misal `PLG-001` atau input manual).
  * Nama lengkap, nomor telepon (format WhatsApp internasional), dan alamat domisili.
* **Dokumentasi Legalitas (KTP / Identitas)**:
  * Pengambilan gambar foto fisik KTP (kamera/galeri) dan penyimpanan ke berkas lokal / cloud storage.
* **Pengaturan Layanan Pelanggan**:
  * Pilihan paket internet yang digunakan.
  * Tanggal pemasangan / mulai aktif langganan.
  * Tanggal jatuh tempo bulanan (*Due Day*, misal setiap tanggal 10).
  * Status pelanggan: **Aktif** atau **Non-Aktif / Isolir**.
* **Integrasi Tagihan Awal**:
  * Saat pelanggan baru didaftarkan, sistem menyediakan opsi untuk otomatis membuat tagihan pertama (kombinasi biaya instalasi + biaya langganan bulan pertama) serta pencatatan pembayaran instan jika langsung dibayar lunas di tempat.

---

## 3. MODUL MASTER PAKET INTERNET & LAYANAN KHUSUS

### Kebutuhan Fungsional:
* **Paket Reguler Bulanan**:
  * Nama paket, kecepatan bandwidth (misal: 10 Mbps, 20 Mbps, 50 Mbps, 100 Mbps).
  * Harga langganan per bulan.
  * Biaya pasang awal default.
  * Sakelar status paket (Aktif / Non-Aktif untuk pendaftaran baru).
* **Paket Khusus Acara / Hajatan**:
  * Skema paket sewa sementara dengan durasi spesifik (misal: paket 3 hari untuk hajatan warga).
  * Dukungan tarif harian kustom (*custom daily rate*).

---

## 4. MODUL SISTEM PENAGIHAN (BILLING ENGINE)

### Kebutuhan Fungsional:
* **Penomoran Invoice Unik**:
  * Format standar otomatis, contoh: `INV-YYYYMM-XXXX`.
* **Siklus Penagihan Otomatis**:
  * Generator tagihan bulanan otomatis berdasarkan siklus berjalan pelanggan aktif.
* **Rincian Komponen Biaya**:
  * Biaya langganan paket bulanan.
  * Biaya pemasangan awal (khusus tagihan pertama).
  * Biaya tambahan (pembelian alat, kabel, router, dll.).
  * Diskon / potongan harga khusus.
* **Status Tagihan (State Management)**:
  * `Belum Bayar` (Unpaid)
  * `Bayar Sebagian` (Partial)
  * `Lunas` (Paid)
  * `Terlambat / Melewati Jatuh Tempo` (Overdue)
  * `Dibatalkan` (Cancelled / Void)

---

## 5. MODUL PEMBAYARAN & KUITANSI (PAYMENT & RECEIPT)

### Kebutuhan Fungsional:
* **Penomoran Kuitansi Unik**:
  * Format standar otomatis, contoh: `KW-YYYYMM-XXXX`.
* **Pencatatan Pembayaran Fleksibel**:
  * Pembayaran lunas dalam 1 kali transaksi.
  * Pembayaran cicilan (parsial), dengan sistem otomatis menghitung sisa tagihan yang belum dibayar.
* **Multi Metode Pembayaran**:
  * Tunai (Cash).
  * Transfer Bank (BCA, BRI, Mandiri, dll.).
  * E-Wallet / QRIS (Dana, Gopay, OVO, ShopeePay, dll.).
* **Penerbitan Bukti Pembayaran (Kuitansi)**:
  * **Kuitansi Dokumen Resmi**: Menampilkan kop nama usaha, nomor kontak, alamat, rincian pembayaran, footer catatan, logo usaha, dan tanda tangan digital.
  * **Kuitansi Struk Thermal Printer**: Format teks ringkas untuk printer kasir Bluetooth (lebar kertas 58mm atau 80mm).
* **Pembatalan Transaksi (Void)**:
  * Kemampuan membatalkan pembayaran dengan mencatat alasan pembatalan dan otomatis mengembalikan status tagihan ke posisi sebelum pembayaran.

---

## 6. MODUL PENGINGAT TAGIHAN & INTEGRASI WHATSAPP

### Kebutuhan Fungsional:
* **Monitoring Status Jatuh Tempo**:
  * Klasifikasi pelanggan mendekati jatuh tempo (H-3, H-1), jatuh tempo hari ini, dan pelanggan yang sudah menunggak/terlambat.
* **Pesan Tagihan Otomatis via WhatsApp**:
  * Pembuatan URL link WhatsApp (`https://wa.me/{nomor}?text={pesan}`) dengan format pesan dinamis berisi:
    * Nama pelanggan & nomor invoice.
    * Periode tagihan & rincian biaya.
    * Batas tanggal jatuh tempo.
    * Nomor rekening / instruksi transfer usaha.
* **Fitur Broadcast Massal**:
  * Daftar antrean pengingat untuk seluruh penunggak sekaligus dalam satu halaman kerja.

---

## 7. MODUL LAPORAN KEUANGAN & EKSPOR DATA

### Kebutuhan Fungsional:
* **Dashboard Metrik Finansial**:
  * Total penerimaan kas bulan berjalan.
  * Total piutang / sisa tunggakan yang belum terbayar.
  * Jumlah tagihan lunas vs tagihan tertunggak.
  * Pertumbuhan jumlah pelanggan aktif vs non-aktif.
* **Ekspor Dokumen**:
  * Ekspor tabel rekapitulasi ke format Spreadsheet **Excel (.xlsx)**.
  * Ekspor data mentah transaksi dan pelanggan ke format **CSV**.

---

## 8. MODUL PENGATURAN USAHA & IDENTITAS BISNIS

### Kebutuhan Fungsional:
* **Profil Entitas Usaha**:
  * Nama ISP / Brand RT-RW Net.
  * Nomor kontak CS & WhatsApp admin.
  * Alamat kantor operasional.
  * Catatan penutup kuitansi / ketentuan layanan.
* **Aset Visual**:
  * Unggah dan kelola Logo Usaha.
  * Unggah dan kelola Tanda Tangan Digital Pengelola.

---

## 9. MODEL DATA ENTITAS (ENTITY-RELATIONSHIP BLUEPRINT)

Berikut struktur data standar (*agnostic schema*) yang dapat diterapkan pada SQL maupun NoSQL:

```
[Admins]
  - id (PK)
  - name
  - email
  - role (Super Admin | Keuangan | Teknisi | Layanan)
  - phone
  - is_active

[Packages]
  - id (PK)
  - name
  - speed
  - monthly_price
  - custom_daily_price
  - installation_fee
  - is_active

[Customers]
  - id (PK)
  - customer_code (Unique)
  - name
  - phone
  - address
  - package_id (FK -> Packages.id)
  - monthly_fee
  - start_date
  - due_day
  - is_active
  - ktp_image_url
  - created_by_admin

[Bills]
  - id (PK)
  - bill_number (Unique)
  - customer_id (FK -> Customers.id)
  - period_month
  - period_year
  - amount
  - paid_amount
  - remaining_amount
  - due_date
  - status (Belum Bayar | Bayar Sebagian | Lunas | Terlambat | Dibatalkan)
  - created_by_admin

[Payments]
  - id (PK)
  - receipt_number (Unique)
  - bill_id (FK -> Bills.id)
  - customer_id (FK -> Customers.id)
  - payment_date
  - amount_paid
  - payment_method (Tunai | Transfer | E-Wallet)
  - is_cancelled
  - received_by_admin

[Settings]
  - key (PK)
  - value
```
