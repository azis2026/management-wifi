# PANDUAN LENGKAP: MIGRASI DARI OFFLINE KE ONLINE (SUPABASE + SUGA APP)
## SISTEM MANAJEMEN WIFI DENGAN DUKUNGAN 4 ADMIN

---

### RINGKASAN JAWABAN
**Apakah bisa?**
👉 **SANGAT BISA (100% Bisa & Gratis)!**

Kombinasi **Flutter + Supabase + Suga App** adalah solusi yang sangat tepat dan hemat biaya:
1. **Supabase (Backend & Database Cloud Gratis)**:
   - Menyimpan seluruh data secara terpusat di cloud PostgreSQL.
   - **Multi Admin (4 Admin)**: Mendukung 4 akun admin dengan wewenang berbeda (Super Admin/Owner, Admin Keuangan/Kasir, Admin Teknisi/Lapangan, Admin Layanan/CS).
   - **Realtime Sync**: Begitu Admin 1 mencatat pembayaran di lapangan melalui HP, layar Admin 2, 3, dan 4 langsung otomatis terupdate detik itu juga tanpa perlu refresh!
   - **Cloud Storage**: Foto KTP pelanggan dan logo kuitansi tersimpan di cloud Supabase sehingga bisa dilihat oleh seluruh admin.
2. **Suga App (`suga.app`) (Hosting Web Gratis)**:
   - Menghubungkan repository git Anda untuk men-deploy aplikasi versi Web.
   - 4 Admin dapat membuka aplikasi melalui browser di Laptop/PC kantor tanpa perlu install aplikasi.
3. **Android APK**:
   - Admin di lapangan tetap bisa menggunakan file APK di smartphone Android masing-masing, dan datanya langsung tersambung online ke database Supabase yang sama!

---

### STRUKTUR 4 AKUN ADMIN DALAM SISTEM

Sistem telah dikonfigurasi dengan 4 akun admin siap pakai:

| No | Nama Admin | Email Default | Password | Role / Wewenang Utama |
|---|---|---|---|---|
| 1 | **Admin Utama (Owner)** | `admin1@wifimanager.com` | `admin123` | **Super Admin**: Akses penuh ke semua fitur, master paket, profil usaha, kuitansi, backup, dan pengaturan cloud. |
| 2 | **Admin Keuangan** | `admin2@wifimanager.com` | `admin123` | **Admin Kasir**: Mencatat pembayaran pelanggan (Tunai, Transfer, E-Wallet), cetak kuitansi PDF/Thermal, melihat laporan omset. |
| 3 | **Admin Teknisi** | `admin3@wifimanager.com` | `admin123` | **Admin Lapangan**: Pendaftaran pelanggan baru, input foto KTP fisik di rumah pelanggan, perpanjangan masa aktif paket WiFi. |
| 4 | **Admin Layanan & CS** | `admin4@wifimanager.com` | `admin123` | **Admin Operasional**: Memantau tagihan jatuh tempo, mengirimkan pengingat WhatsApp massal, melayani komplain pelanggan. |

> **Catatan**: Email dan nama masing-masing admin dapat Anda sesuaikan kapan saja melalui menu **Lainnya > Kelola 4 Akun Admin**.

---

### LANGKAH 1: MEMBUAT PROYEK SUPABASE GRATIS (5 MENIT)

1. Buka situs [https://supabase.com](https://supabase.com) melalui browser.
2. Klik tombol **Start your project** atau **Sign In** (bisa langsung login menggunakan akun GitHub atau Google).
3. Klik tombol **New Project** (Buat Proyek Baru).
4. Isi formulir pembuatan:
   - **Name**: `WiFi Manager`
   - **Database Password**: Buat password yang kuat (simpan password ini).
   - **Region**: Pilih **Singapore (`ap-southeast-1`)** agar koneksi dari Indonesia sangat cepat dan responsif.
   - **Pricing Plan**: Pilih **Free Tier** ($0 / Bulan).
5. Klik **Create new project** dan tunggu sekitar 1-2 menit hingga proses pembuatan database selesai.

---

### LANGKAH 2: MENJALANKAN SKRIP DATABASE (1-KLIK)

1. Di dashboard Supabase proyek Anda, lihat menu bilah kiri lalu klik **SQL Editor** (ikon terminal/kueri).
2. Klik tombol **New query**.
3. Buka berkas [supabase_schema.sql](file:///c:/Users/Program1/Music/MANAGEMENT%20WIFI/supabase_schema.sql) yang sudah kami buatkan di folder proyek ini.
4. Salin (Copy) seluruh isi berkas [supabase_schema.sql](file:///c:/Users/Program1/Music/MANAGEMENT%20WIFI/supabase_schema.sql) tersebut, lalu tempelkan (Paste) ke SQL Editor Supabase.
5. Klik tombol hijau **Run** (atau tekan `Ctrl + Enter`).
6. Muncul pesan `Success. No rows returned`.
   *(Seluruh tabel paket, pelanggan, tagihan, pembayaran, 4 admin, security RLS, dan storage bucket foto KTP otomatis selesai dibuat!)*

---

### LANGKAH 3: MENGAMBIL URL & API KEY DARI SUPABASE

1. Di dashboard Supabase, klik ikon roda gigi **Project Settings** (di pojok kiri bawah).
2. Pilih submenu **API**.
3. Cari dua informasi berikut:
   - **Project URL**: Formatnya mirip `https://xyzcompany.supabase.co`
   - **anon / public key**: Kunci panjang berupa token enkripsi `eyJhbGciOiJIUzI1Ni...`
4. Salin kedua nilai tersebut.

---

### LANGKAH 4: MENGHUBUNGKAN APLIKASI DAN MIGRASI DATA

1. Buka aplikasi **WiFi Manager** di HP atau Laptop Anda.
2. Buka tab **Lainnya** > pilih menu **Supabase Cloud & Sinkronisasi**.
3. Tempelkan **Project URL** dan **Anon Key** yang sudah Anda dapatkan pada Langkah 3.
4. Klik tombol **Simpan & Uji Koneksi**.
   - Indikator status akan langsung berubah menjadi **🟢 ONLINE (Terhubung ke Cloud)**.
5. **Migrasikan Data Offline Lama Anda**:
   - Jika sebelumnya Anda sudah memiliki data pelanggan atau paket di aplikasi offline ini, cukup klik tombol **Upload (Migrasi SQLite Offline ke Cloud)**.
   - Sistem akan menyalin seluruh data dari HP Anda ke Supabase Cloud dalam hitungan detik.
   - Sekarang, ke-4 admin langsung bisa melihat data yang sama di perangkat mereka masing-masing!

---

### LANGKAH 5: CARA MASUK SEBAGAI SALAH SATU DARI 4 ADMIN

1. Di Beranda atau di menu **Lainnya > Kelola 4 Akun Admin**, klik tombol **Ganti Admin / Login**.
2. Anda akan melihat kartu 4 admin:
   - Klik salah satu kartu admin untuk langsung berpindah akun (misalnya beralih ke *Admin 2 - Keuangan* saat ingin bertugas sebagai kasir).
   - Atau Anda bisa login menggunakan email & password.
3. Setiap transaksi pembayaran dan penagihan yang Anda lakukan akan otomatis mencatat nama admin yang sedang aktif (`received_by_admin` / `created_by_admin`).

---

### LANGKAH 6: DEPLOY KE SUGA APP (`suga.app`) (VERSI WEB)

Suga App adalah platform cloud modern yang mendukung deployment aplikasi full-stack dan container web dengan sangat cepat.

Kami telah menyiapkan berkas konfigurasi siap pakai:
- [Dockerfile](file:///c:/Users/Program1/Music/MANAGEMENT%20WIFI/Dockerfile): Docker multi-stage resmi untuk build Flutter Web & Nginx.
- [nginx.conf](file:///c:/Users/Program1/Music/MANAGEMENT%20WIFI/nginx.conf): Konfigurasi web server Nginx yang sudah dioptimalkan untuk Flutter Single Page Application (SPA).
- [.dockerignore](file:///c:/Users/Program1/Music/MANAGEMENT%20WIFI/.dockerignore): Mempercepat proses build container.

#### Cara Deploy ke Suga App:
1. Buat repositori Git untuk proyek ini di GitHub atau GitLab:
   ```bash
   git init
   git add .
   git commit -m "feat: online supabase multi admin & suga app deploy"
   git remote add origin https://github.com/username-anda/wifi-manager.git
   git push -u origin main
   ```
2. Buka situs [https://suga.app](https://suga.app) dan login dengan akun Anda.
3. Klik **New Service / New Project**, lalu hubungkan repositori GitHub/GitLab Anda.
4. Suga App akan otomatis mendeteksi keberadaan berkas `Dockerfile` di proyek Anda.
5. Klik tombol **Deploy**.
6. Tunggu proses build selesai. Suga App akan memberikan URL publik gratis (misal: `https://wifi-manager.suga.app`) yang bisa langsung dibuka oleh ke-4 admin dari laptop mana pun di seluruh dunia!

---

### LANGKAH 7: MEMBAGIKAN APK ANDROID KE 4 ADMIN

Jika admin lapangan atau kasir ingin menggunakan aplikasi di HP Android masing-masing:
1. Jalankan script build APK release:
   ```powershell
   .\build_apk.ps1
   ```
2. Bagikan file `WiFi-Manager-Release.apk` ke smartphone 4 admin melalui WhatsApp atau Google Drive.
3. Pasang APK tersebut di masing-masing HP.
4. Buka menu **Lainnya > Supabase Cloud & Sinkronisasi**, masukkan URL & Anon Key Supabase yang sama.
5. Selesai! Semua HP admin sekarang terhubung secara real-time ke satu pusat data yang sama.

---

### KEUNGGULAN SISTEM SETELAH AKTIF ONLINE:
✅ **Anti Kehilangan Data**: Jika HP salah satu admin rusak atau hilang, semua data pelanggan & keuangan tetap aman 100% di cloud Supabase.
✅ **Transparansi Keuangan**: Setiap pembayaran tercatat siapa admin penerimanya, jam berapa, dan metode pembayarannya (Tunai / Transfer).
✅ **Tetap Tahan Offline**: Jika tiba-tiba sinyal internet di lapangan mati, aplikasi tetap bisa membaca data lokal perangkat dan menyinkronkannya kembali saat internet aktif.
