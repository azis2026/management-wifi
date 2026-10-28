# BUKU PANDUAN PENGGUNAAN LENGKAP
## APLIKASI WIFI MANAGER (MANAJEMEN RT/RW NET & ISP MANDIRI)

---

### DAFTAR ISI
1. [Tentang Aplikasi](#1-tentang-aplikasi)
2. [Instalasi Aplikasi](#2-instalasi-aplikasi)
3. [Langkah Awal: Pengaturan Profil Perusahaan](#3-langkah-awal-pengaturan-profil-perusahaan)
4. [Manajemen Paket Internet & Paket Hajatan](#4-manajemen-paket-internet--paket-hajatan)
5. [Manajemen Pelanggan (CRUD & Foto KTP)](#5-manajemen-pelanggan-crud--foto-ktp)
6. [Pembuatan & Pengelolaan Tagihan](#6-pembuatan--pengelolaan-tagihan)
7. [Pencatatan Pembayaran & Cetak Kuitansi](#7-pencatatan-pembayaran--cetak-kuitansi)
8. [Pengingat Tagihan & Notifikasi WhatsApp](#8-pengingat-tagihan--notifikasi-whatsapp)
9. [Laporan Keuangan & Ekspor Excel / Spreadsheet](#9-laporan-keuangan--ekspor-excel--spreadsheet)
10. [Backup & Restore Data (Keamanan Data)](#10-backup--restore-data-keamanan-data)
11. [FAQ & Solusi Masalah](#11-faq--solusi-masalah)

---

### 1. TENTANG APLIKASI

**WiFi Manager** adalah aplikasi manajemen operasional lengkap untuk pengelola WiFi RT/RW Net, ISP lokal, dan penyedia jasa internet mandiri. 

> **100% Offline-First & Bebas Biaya Langganan Server**: Seluruh data pelanggan, tagihan, dan pembayaran disimpan langsung di database lokal perangkat Anda. Aplikasi dapat bekerja tanpa koneksi internet, sangat cepat, dan menjaga privasi data pelanggan Anda.

#### Fitur Utama:
- 📋 **Database Pelanggan**: ID manual/otomatis, foto KTP, kontak WhatsApp, status aktif/nonaktif.
- ⚡ **Paket Fleksibel**: Mendukung paket bulanan reguler dan paket hajatan/acara khusus (3 hari).
- 🧾 **Sistem Tagihan Otomatis**: Buat tagihan perorangan atau tagihan massal untuk seluruh pelanggan aktif dalam 1 klik.
- 💵 **Pencatatan Pembayaran Cepat**: Pilihan bayar lunas atau cicilan (parsial), multi metode pembayaran (Tunai, Transfer, E-Wallet).
- 🖨️ **Kuitansi PDF & Thermal**: Dilengkapi nomor kuitansi unik, logo perusahaan, dan tanda tangan digital.
- 📲 **Integrasi WhatsApp**: Kirim rincian tagihan perorangan atau rekap tunggakan massal via WhatsApp.
- 📊 **Laporan & Ekspor Excel**: Rekap omset harian/mingguan/bulanan dan ekspor ke format CSV / Excel / Google Sheets.

---

### 2. INSTALASI APLIKASI

Berkas APK rilis aplikasi telah tersedia di:
- **[WiFi-Manager-Release.apk](file:///c:/Users/Payiss/Music/MANAGEMENT%20WIFI/WiFi-Manager-Release.apk)** (Folder utama proyek)
- **[app-release.apk](file:///c:/Users/Payiss/Music/MANAGEMENT%20WIFI/build/app/outputs/flutter-apk/app-release.apk)** (Folder output build)

#### Cara Pasang di HP Android:
1. Pindahkan berkas `WiFi-Manager-Release.apk` ke HP Android Anda (melalui WhatsApp Dokumen, kabel USB, atau Google Drive).
2. Di HP Android, buka file manager dan ketuk berkas `.apk` tersebut.
3. Pilih **Install**.
4. Jika muncul peringatan keamanan *"Izinkan instalasi dari sumber ini"* (biasa muncul untuk aplikasi di luar Play Store), pilih **Pengaturan** lalu aktifkan izinnya.
5. Selesai! Buka aplikasi **WiFi Manager**.

---

### 3. LANGKAH AWAL: PENGATURAN PROFIL PERUSAHAAN

Sebelum mencetak kuitansi atau mengirim WhatsApp ke pelanggan, atur identitas usaha Anda terlebih dahulu.

#### Langkah-langkah:
1. Buka tab **Lainnya** (ikon menu paling kanan di navigasi bawah).
2. Pilih menu **Profil Perusahaan & Pengaturan**.
3. Isi informasi resmi:
   - **Nama Perusahaan / Usaha**: Contoh `WiFi Net Mandiri` atau `Bintang Net RT 05`.
   - **Nomor Kontak / WhatsApp Admin**: Contoh `081234567890`. Nomor ini akan otomatis dicantumkan di pesan tagihan WhatsApp dan kuitansi.
   - **Alamat Kantor / Domisili**: Alamat fisik operasional Anda.
   - **Catatan Footer Kuitansi**: Pesan di bagian bawah kuitansi, misalnya *"Terima kasih atas pembayaran tepat waktu. Layanan bantuan hubungi 0812-XXXX-XXXX"*.
4. **Upload Logo Usaha**:
   - Ketuk tombol **Pilih Logo** untuk memilih gambar dari galeri HP.
   - Logo ini akan otomatis tampil di kop kuitansi PDF resmi.
5. **Upload Tanda Tangan Digital**:
   - Siapkan foto tanda tangan di atas kertas putih.
   - Ketuk tombol **Pilih Tanda Tangan** untuk mengunggahnya. Tanda tangan ini akan tercetak di kuitansi sebagai pengesahan sah.
6. Ketuk **Simpan Perubahan**.

---

### 4. MANAJEMEN PAKET INTERNET & PAKET HAJATAN

Aplikasi mendukung dua kategori paket:
1. **Paket Bulanan Reguler**: Paket langganan standar 10 Mbps, 20 Mbps, 30 Mbps, 50 Mbps, dll.
2. **Paket Hajatan / Acara Khusus (3 Hari)**:
   - **Hajatan 50 Mbps**: Rp50.000 / 3 hari.
   - **Hajatan 100 Mbps**: Rp75.000 / 3 hari.

#### Cara Mengelola Paket:
1. Buka tab **Lainnya** > pilih **Paket WiFi**.
2. Anda akan melihat daftar semua paket yang tersedia beserta kecepatannya.
3. Gunakan sakelar toggle di sisi kanan untuk mengaktifkan atau menonaktifkan paket tertentu.

> **Tips**: Paket Hajatan secara otomatis diberi label khusus oranye dan menghasilkan format kuitansi acara khusus saat pelanggan hajatan melakukan pembayaran.

---

### 5. MANAJEMEN PELANGGAN (CRUD & FOTO KTP)

#### A. Menambahkan Pelanggan Baru:
1. Buka tab **Pelanggan** (atau tekan tombol `+ Tambah Pelanggan` di Beranda).
2. Tekan tombol FAB **+ Tambah Pelanggan**.
3. Isi formulir:
   - **ID Pelanggan (Manual)**: Anda bebas mengisi kode sendiri (misal `PLG-001`, `RT02-09`) atau biarkan sistem membuatkan kode otomatis jika dikosongkan.
   - **Nama Lengkap**: Nama pelanggan.
   - **Nomor WhatsApp**: Awali dengan `08...` (sistem akan mengonversi otomatis ke format WhatsApp internasional).
   - **Alamat Pemasangan**: Alamat rumah/blok/RT/RW.
   - **Pilih Paket WiFi**: Pilih dari daftar paket bulanan atau hajatan.
   - **Tanggal Pemasangan / Mulai**: Tanggal aktivasi awal.
   - **Upload Foto KTP**: Ketuk **Pilih Foto KTP** untuk mendokumentasikan kartu identitas pelanggan langsung dari kamera atau galeri.
4. Ketuk **Simpan Pelanggan**.

#### B. Mencari & Memfilter Pelanggan:
- Gunakan bilah pencarian di bagian atas untuk mencari nama, no HP, atau kode pelanggan secara instan.
- Gunakan tombol filter di bawah bilah pencarian:
  - **Semua**: Seluruh pelanggan terdaftar.
  - **Hanya Aktif**: Pelanggan dengan status layanan aktif.
  - **Ada Tunggakan ⚠️**: Hanya menampilkan pelanggan yang memiliki tagihan belum lunas.

#### C. Mengedit & Menghapus Pelanggan:
- Buka detail pelanggan dengan mengetuk nama pelanggan di daftar.
- **Edit**: Ketuk ikon pensil (Edit) di pojok kanan atas untuk memperbarui alamat, no HP, paket, atau foto KTP.
- **Hapus**: Ketuk ikon tempat sampah (Hapus) di pojok kanan atas. Sistem akan meminta konfirmasi ganda untuk mencegah penghapusan yang tidak disengaja.

---

### 6. PEMBUATAN & PENGELOLAAN TAGIHAN

Tagihan adalah dasar dari pencatatan piutang dan pembayaran.

#### A. Membuat Tagihan Massal (Awal Bulan):
1. Buka tab **Tagihan** > ketuk ikon `+` di kanan atas (atau via tombol Cepat di Beranda).
2. Aktifkan sakelar **Buat Tagihan Massal**.
3. Tentukan **Bulan** dan **Tahun** tagihan (misal: *November 2026*).
4. Tentukan **Tanggal Jatuh Tempo** (misal tanggal 10 setiap bulan).
5. Ketuk **Generate Tagihan Massal**. Sistem secara otomatis membuatkan lembar tagihan untuk seluruh pelanggan aktif sesuai harga paket masing-masing!

#### B. Membuat Tagihan Perorangan (Termasuk Paket Hajatan):
1. Masuk ke halaman **Buat Tagihan**.
2. Nonaktifkan mode massal (mode perorangan).
3. Pilih nama pelanggan dari dropdown.
4. Sistem akan otomatis mengisi paket dan nominal standar pelanggan tersebut. Anda dapat menyesuaikan nominal jika terdapat biaya instalasi atau penyesuaian khusus.
5. Ketuk **Simpan Tagihan**.

#### C. Status Tagihan:
- 🔴 **Belum Bayar**: Belum ada pembayaran masuk sama sekali.
- 🟡 **Bayar Sebagian**: Pelanggan telah mencicil namun masih ada sisa tagihan.
- ⚠️ **Melewati Jatuh Tempo**: Tagihan belum lunas dan telah melewati tanggal jatuh tempo.
- 🟢 **Lunas**: Tagihan sudah dibayar penuh.

---

### 7. PENCATATAN PEMBAYARAN & CETAK KUITANSI

#### A. Mencatat Pembayaran Masuk:
1. Masuk ke tab **Beranda** atau **Tagihan**.
2. Pada tagihan yang ingin dibayar, ketuk tombol **Bayar**.
   *(Atau dari halaman Detail Pelanggan > ketuk Bayar).*
3. Pilih atau verifikasi nominal:
   - Gunakan chip **[Bayar Lunas]** untuk mengisi seluruh sisa tagihan.
   - Gunakan chip **[Cicil 50%]** jika pelanggan membayar separuh dulu.
   - Atau ketik nominal manual sesuai uang yang diserahkan pelanggan.
4. Pilih **Metode Pembayaran**:
   - **Tunai** (Cash)
   - **Transfer Bank**
   - **E-Wallet** (DANA, OVO, GoPay, QRIS)
   - **Lainnya**
5. Masukkan catatan tambahan jika perlu (misal: *"Diterima via transfer BCA"*).
6. Ketuk **Simpan Pembayaran**.

#### B. Mencetak & Membagikan Kuitansi:
Setelah pembayaran disimpan, Anda langsung diarahkan ke pratinjau **Kuitansi Resmi**:
- **Nomor Kuitansi Unik**: Dibuat otomatis dengan format `KW-YYYYMMDD-XXXX`.
- **Cetak ke Printer (PDF / Thermal)**: Ketuk tombol **Cetak Kuitansi** untuk mencetak via WiFi printer atau Bluetooth thermal printer.
- **Kirim Kuitansi Digital**: Ketuk tombol **Bagikan via WhatsApp / PDF** untuk mengirim berkas kuitansi langsung ke WhatsApp pelanggan.

#### C. Pembatalan Pembayaran (Void / Rollback):
Jika kasir salah memasukkan nominal pembayaran:
1. Buka tab **Lainnya** > **Riwayat Transaksi**.
2. Pilih pembayaran yang bersangkutan.
3. Ketuk opsi **Batalkan Transaksi**, masukkan alasan pembatalan.
4. Sistem secara otomatis mengembalikan sisa tagihan pelanggan ke kondisi semula!

---

### 8. PENGINGAT TAGIHAN & NOTIFIKASI WHATSAPP

#### A. Pengingat Perorangan (1-Tap):
- Di halaman **Beranda** (pada daftar Tagihan Mendekati Jatuh Tempo) atau di halaman **Daftar Tagihan**, cukup ketuk **ikon WhatsApp**.
- Aplikasi akan otomatis menyusun draf pesan penagihan yang rapi dan sopan lengkap dengan nama pelanggan, nomor tagihan, rincian paket, jatuh tempo, serta nomor rekening Anda.
- Ketuk kirim di aplikasi WhatsApp!

#### B. Pengingat Tagihan Massal (Broadcast / Rekap):
1. Buka tab **Lainnya** > pilih **Pengingat Jatuh Tempo**.
2. Anda akan melihat daftar seluruh pelanggan yang belum melunasi tagihannya.
3. Di bagian atas terdapat kartu ringkasan total pelanggan nunggak dan total rupiah yang belum tertagih.
4. Ketuk tombol **Kirim Pengingat Massal**:
   - Sistem akan menyusun seluruh daftar penagihan dalam satu format rekap pesan WhatsApp lengkap.
   - Anda dapat membagikannya ke WhatsApp grup tim penagih, broadcast pesan, atau menyalin teksnya ke clipboard.

---

### 9. LAPORAN KEUANGAN & EKSPOR EXCEL / SPREADSHEET

1. Buka tab **Lainnya** > pilih **Laporan Keuangan**.
2. **Ringkasan Kartu Eksekutif**:
   - Pendapatan Hari Ini
   - Pendapatan 7 Hari Terakhir
   - Pendapatan Bulan Berjalan
3. **Penyaringan Rentang Tanggal**:
   - Gunakan tombol preset cepat: **[Bulan Ini]**, **[30 Hari]**, **[Bulan Lalu]**, atau **[Tahun Ini]**.
   - Anda juga dapat memilih rentang tanggal kustom dengan mengetuk bilah tanggal.
4. **Analisis Metode Pembayaran**:
   - Menampilkan visual progress bar dan persentase uang yang masuk lewat Tunai vs Transfer Bank vs E-Wallet.
5. **Ekspor ke Excel / Spreadsheet**:
   - Ketuk kartu hijau **Ekspor ke Excel / Spreadsheet**.
   - Berkas spreadsheet `.csv` (dengan encoding UTF-8 BOM yang langsung rapi di Excel tanpa teks berantakan) akan dibuat.
   - Anda dapat langsung membuka file tersebut di Microsoft Excel, WPS Office, atau mengunggahnya ke Google Sheets.

---

### 10. BACKUP & RESTORE DATA (KEAMANAN DATA)

Karena seluruh data tersimpan di HP Anda, lakukan pencadangan (backup) berkala minimal 1 minggu sekali.

#### A. Melakukan Backup:
1. Buka tab **Lainnya** > pilih **Pencadangan & Pemulihan (Backup & Restore)**.
2. Ketuk tombol **Cadangkan Database Sekarang**.
3. Sistem akan menghasilkan berkas cadangan dengan stempel tanggal (misal `wifi_manager_backup_2026-10-26.db`).
4. Bagikan dan simpan berkas ini ke Google Drive pribadi, kirim ke WhatsApp sendiri, atau simpan di memori eksternal.

#### B. Memulihkan Data (Ganti HP):
1. Di HP baru, pasang aplikasi **WiFi Manager**.
2. Salin berkas backup `.db` ke penyimpanan HP.
3. Masuk ke menu **Pencadangan & Pemulihan** > ketuk **Pulihkan Database**.
4. Pilih file cadangan Anda. Seluruh data pelanggan, paket, tagihan, dan kuitansi akan kembali utuh seperti semula!

---

### 11. FAQ & SOLUSI MASALAH

**Q: Apakah aplikasi ini membutuhkan koneksi internet untuk bekerja?**  
A: Tidak. Aplikasi ini bekerja 100% secara offline. Internet hanya dibutuhkan saat Anda mengirimkan pesan/kuitansi ke aplikasi WhatsApp.

**Q: Bagaimana jika nomor pelanggan belum diawali kode 62 (misal diawali 0812)?**  
A: Sistem secara otomatis mendeteksi dan mengubah `08...` menjadi `628...` saat memproses tautan WhatsApp. Anda cukup mengetik nomor biasa seperti yang biasa digunakan.

**Q: Bagaimana cara mencetak kuitansi ke printer thermal bluetooth?**  
A: Di layar pratinjau kuitansi, pilih tombol **Cetak Kuitansi**. Pilih printer bluetooth yang telah dipasangkan (paired) dengan HP Android Anda pada dialog pencetakan Android.

**Q: Bisakah data diekspor langsung ke spreadsheet di komputer?**  
A: Ya. Hasil ekspor CSV dari menu Laporan Keuangan dapat langsung dibuka di Microsoft Excel komputer, LibreOffice Calc, maupun Google Sheets tanpa perlu konversi apapun.

---
*Dokumentasi Resmi WiFi Manager v1.0 • Dikembangkan untuk Pengelola Jaringan Mandiri & RT/RW Net.*
