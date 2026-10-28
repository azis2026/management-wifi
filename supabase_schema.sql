-- ==============================================================================
-- SKRIP DATABASE SUPABASE UNTUK WIFI MANAGER (MULTI ADMIN ONLINE)
-- ==============================================================================
-- Cara Menjalankan:
-- 1. Buka dashboard Supabase (https://app.supabase.com)
-- 2. Pilih Project Anda -> Buka menu "SQL Editor" di bilah kiri
-- 3. Klik "New Query", paste seluruh isi berkas ini, lalu tekan tombol "Run" (Ctrl + Enter)
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. TABEL ADMIN (4 AKUN ADMIN MULTI-USER)
CREATE TABLE IF NOT EXISTS public.admins (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL DEFAULT 'Admin', -- 'Super Admin', 'Admin Keuangan', 'Admin Teknisi', 'Admin Layanan'
    phone TEXT DEFAULT '',
    avatar_url TEXT,
    password_hash TEXT DEFAULT '123456', -- Password default untuk login
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. TABEL PAKET INTERNET
CREATE TABLE IF NOT EXISTS public.packages (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    speed TEXT NOT NULL,
    monthly_price BIGINT NOT NULL,
    custom_daily_price BIGINT NOT NULL DEFAULT 0,
    installation_fee BIGINT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. TABEL PELANGGAN
CREATE TABLE IF NOT EXISTS public.customers (
    id BIGSERIAL PRIMARY KEY,
    customer_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    address TEXT NOT NULL,
    package_id BIGINT REFERENCES public.packages(id) ON DELETE SET NULL,
    package_name TEXT NOT NULL,
    package_speed TEXT DEFAULT '',
    monthly_fee BIGINT NOT NULL,
    install_date TEXT NOT NULL,
    start_date TEXT NOT NULL,
    installation_fee BIGINT NOT NULL DEFAULT 0,
    due_day INT NOT NULL DEFAULT 10,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT DEFAULT '',
    ktp_image_path TEXT,
    created_by_admin TEXT DEFAULT 'Admin',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. TABEL TAGIHAN (BILLS)
CREATE TABLE IF NOT EXISTS public.bills (
    id BIGSERIAL PRIMARY KEY,
    bill_number TEXT UNIQUE NOT NULL,
    customer_id BIGINT REFERENCES public.customers(id) ON DELETE CASCADE,
    customer_code TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    customer_phone TEXT DEFAULT '',
    package_id BIGINT,
    package_name TEXT NOT NULL,
    period_month INT NOT NULL,
    period_year INT NOT NULL,
    period_start TEXT DEFAULT '',
    period_end TEXT DEFAULT '',
    amount BIGINT NOT NULL,
    paid_amount BIGINT NOT NULL DEFAULT 0,
    remaining_amount BIGINT NOT NULL,
    installation_fee BIGINT NOT NULL DEFAULT 0,
    subscription_fee BIGINT NOT NULL DEFAULT 0,
    additional_fee BIGINT NOT NULL DEFAULT 0,
    discount BIGINT NOT NULL DEFAULT 0,
    is_first_bill BOOLEAN NOT NULL DEFAULT FALSE,
    due_date TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Belum Bayar',
    notes TEXT DEFAULT '',
    cancel_reason TEXT DEFAULT '',
    created_by_admin TEXT DEFAULT 'Admin',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. TABEL PEMBAYARAN (PAYMENTS)
CREATE TABLE IF NOT EXISTS public.payments (
    id BIGSERIAL PRIMARY KEY,
    receipt_number TEXT UNIQUE NOT NULL,
    bill_id BIGINT REFERENCES public.bills(id) ON DELETE CASCADE,
    bill_number TEXT NOT NULL,
    customer_id BIGINT REFERENCES public.customers(id) ON DELETE CASCADE,
    customer_code TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    payment_date TEXT NOT NULL,
    amount_paid BIGINT NOT NULL,
    payment_method TEXT NOT NULL,
    notes TEXT DEFAULT '',
    is_cancelled BOOLEAN NOT NULL DEFAULT FALSE,
    cancel_reason TEXT DEFAULT '',
    received_by_admin TEXT DEFAULT 'Admin',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. TABEL PENGATURAN & PROFIL USAHA
CREATE TABLE IF NOT EXISTS public.settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- INDEXING UNTUK KECEPATAN QUERY TINGGI
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_customers_code ON public.customers(customer_code);
CREATE INDEX IF NOT EXISTS idx_customers_active ON public.customers(is_active);
CREATE INDEX IF NOT EXISTS idx_bills_customer ON public.bills(customer_id);
CREATE INDEX IF NOT EXISTS idx_bills_number ON public.bills(bill_number);
CREATE INDEX IF NOT EXISTS idx_bills_status ON public.bills(status);
CREATE INDEX IF NOT EXISTS idx_bills_due_date ON public.bills(due_date);
CREATE INDEX IF NOT EXISTS idx_payments_bill ON public.payments(bill_id);
CREATE INDEX IF NOT EXISTS idx_payments_receipt ON public.payments(receipt_number);
CREATE INDEX IF NOT EXISTS idx_payments_date ON public.payments(payment_date);

-- ==============================================================================
-- KEAMANAN: ROW LEVEL SECURITY (RLS)
-- Mengizinkan akses aman untuk aplikasi client menggunakan Supabase Anon Key
-- ==============================================================================
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- Kebijakan Akses Penuh untuk App (Anon Key & Authenticated Users)
DO $$
BEGIN
    DROP POLICY IF EXISTS "Akses Penuh Admins" ON public.admins;
    CREATE POLICY "Akses Penuh Admins" ON public.admins FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Akses Penuh Packages" ON public.packages;
    CREATE POLICY "Akses Penuh Packages" ON public.packages FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Akses Penuh Customers" ON public.customers;
    CREATE POLICY "Akses Penuh Customers" ON public.customers FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Akses Penuh Bills" ON public.bills;
    CREATE POLICY "Akses Penuh Bills" ON public.bills FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Akses Penuh Payments" ON public.payments;
    CREATE POLICY "Akses Penuh Payments" ON public.payments FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Akses Penuh Settings" ON public.settings;
    CREATE POLICY "Akses Penuh Settings" ON public.settings FOR ALL USING (true) WITH CHECK (true);
END $$;

-- ==============================================================================
-- FITUR REALTIME: Sinkronisasi instan ke seluruh 4 Admin secara bersamaan
-- ==============================================================================
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.admins;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.packages;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.customers;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bills;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.payments;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.settings;
EXCEPTION WHEN OTHERS THEN
    -- Abaikan jika tabel sudah terdaftar di publication
END $$;

-- ==============================================================================
-- DATA AWAL (SEEDING) 4 AKUN ADMIN
-- ==============================================================================
INSERT INTO public.admins (id, name, email, role, phone, password_hash, is_active)
VALUES
    ('admin-01', 'Admin Utama (Owner)', 'admin1@wifimanager.com', 'Super Admin', '081234567801', 'admin123', true),
    ('admin-02', 'Admin Keuangan & Kasir', 'admin2@wifimanager.com', 'Admin Keuangan', '081234567802', 'admin123', true),
    ('admin-03', 'Admin Lapangan & Teknisi', 'admin3@wifimanager.com', 'Admin Teknisi', '081234567803', 'admin123', true),
    ('admin-04', 'Admin Layanan & CS', 'admin4@wifimanager.com', 'Admin Layanan', '081234567804', 'admin123', true)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    phone = EXCLUDED.phone;

-- ==============================================================================
-- DATA AWAL (SEEDING) PAKET WIFI
-- ==============================================================================
INSERT INTO public.packages (name, speed, monthly_price, installation_fee, is_active)
VALUES
    ('Paket Hemat', '6 Mbps', 60000, 0, true),
    ('Paket Hemat', '11 Mbps', 85000, 0, true),
    ('Paket Keluar', '20 Mbps', 111000, 0, true),
    ('Paket 30 Mbps', '30 Mbps', 150000, 0, true),
    ('Paket 50 Mbps', '50 Mbps', 185000, 0, true),
    ('Paket 100 Mbps', '100 Mbps', 226000, 0, true)
ON CONFLICT DO NOTHING;

-- ==============================================================================
-- DATA AWAL PENGATURAN USAHA
-- ==============================================================================
INSERT INTO public.settings (key, value)
VALUES
    ('business_name', 'WiFi Net Mandiri'),
    ('contact_phone', '0812-3456-7890'),
    ('address', 'Jl. Merdeka No. 10'),
    ('receipt_footer', 'Terima kasih atas pembayaran Anda. Simpan bukti ini sebagai tanda lunas.'),
    ('logo_path', ''),
    ('signature_path', '')
ON CONFLICT (key) DO NOTHING;

-- ==============================================================================
-- STORAGE BUCKET UNTUK FOTO KTP & LOGO PERUSAHAAN (CLOUD STORAGE)
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('wifi_storage', 'wifi_storage', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public Read Wifi Storage" ON storage.objects
FOR SELECT USING (bucket_id = 'wifi_storage');

CREATE POLICY "Public Insert Wifi Storage" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'wifi_storage');

CREATE POLICY "Public Update Wifi Storage" ON storage.objects
FOR UPDATE USING (bucket_id = 'wifi_storage');

CREATE POLICY "Public Delete Wifi Storage" ON storage.objects
FOR DELETE USING (bucket_id = 'wifi_storage');

-- SELESAI
