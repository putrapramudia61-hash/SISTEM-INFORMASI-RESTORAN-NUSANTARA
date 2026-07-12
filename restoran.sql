PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS bookings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT,
    guests INTEGER NOT NULL CHECK (guests > 0),
    booking_date TEXT NOT NULL,
    booking_time TEXT NOT NULL,
    occasion TEXT NOT NULL,
    note TEXT,
    status TEXT NOT NULL DEFAULT 'booked',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS menus (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    origin TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('makanan', 'minuman', 'paket')),
    price INTEGER NOT NULL CHECK (price >= 0),
    spice TEXT NOT NULL,
    icon TEXT NOT NULL,
    image TEXT NOT NULL,
    description TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    total INTEGER NOT NULL CHECK (total >= 0),
    payment_method TEXT NOT NULL DEFAULT 'cash',
    booking_id INTEGER,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS order_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id INTEGER NOT NULL,
    menu_id TEXT NOT NULL,
    menu_name TEXT NOT NULL,
    price INTEGER NOT NULL CHECK (price >= 0),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    subtotal INTEGER NOT NULL CHECK (subtotal >= 0),
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (menu_id) REFERENCES menus(id)
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_menu_id ON order_items(menu_id);
CREATE INDEX IF NOT EXISTS idx_bookings_booking_date ON bookings(booking_date);

INSERT OR IGNORE INTO menus
(id, name, origin, category, price, spice, icon, image, description)
VALUES
('rendang', 'Rendang Daging', 'Sumatera Barat', 'makanan', 42000, 'Pedas gurih', 'rendang', 'assets/restoran/rendang-daging.jpg', 'Daging sapi empuk dimasak perlahan dengan santan, cabai, dan rempah Minang.'),
('sate', 'Sate Ayam Madura', 'Madura', 'makanan', 32000, 'Manis pedas', 'sate', 'assets/restoran/sate-ayam-madura.webp', 'Sate ayam bakar arang dengan bumbu kacang, kecap, lontong, dan acar.'),
('rawon', 'Rawon Surabaya', 'Jawa Timur', 'makanan', 38000, 'Hangat rempah', 'soup', 'assets/restoran/rawon-surabaya.jpg', 'Sup daging kuah kluwek berwarna hitam dengan tauge pendek dan telur asin.'),
('gudeg', 'Gudeg Jogja', 'Yogyakarta', 'makanan', 35000, 'Manis legit', 'rice', 'assets/restoran/gudeg-jogja.jpg', 'Nangka muda, ayam opor, telur pindang, krecek, dan nasi hangat.'),
('soto', 'Soto Betawi', 'Jakarta', 'makanan', 40000, 'Gurih santan', 'soup', 'assets/restoran/soto-betawi.jpg', 'Kuah santan susu dengan daging sapi, kentang, tomat, dan emping.'),
('nasi-liwet', 'Nasi Liwet Solo', 'Jawa Tengah', 'makanan', 34000, 'Gurih lembut', 'rice', 'assets/restoran/nasi-liwet-solo.jpg', 'Nasi gurih, suwiran ayam, sayur labu, telur, dan areh santan.'),
('ayam-taliwang', 'Ayam Taliwang', 'Lombok', 'makanan', 45000, 'Pedas kuat', 'chicken', 'assets/restoran/ayam-taliwang.jpg', 'Ayam bakar bumbu cabai Lombok dengan plecing kangkung dan nasi putih.'),
('pempek', 'Pempek Kapal Selam', 'Palembang', 'makanan', 30000, 'Asam pedas', 'snack', 'assets/restoran/pempek-kapal-selam.jpg', 'Pempek isi telur dengan kuah cuko, timun, dan mi kuning.'),
('cendol', 'Es Cendol Dawet', 'Jawa', 'minuman', 18000, 'Segar manis', 'drink', 'assets/restoran/es-cendol-dawet.jpg', 'Cendol pandan, santan, gula aren cair, dan es serut.'),
('wedang', 'Wedang Jahe', 'Nusantara', 'minuman', 16000, 'Hangat', 'tea', 'assets/restoran/es_cendol_nangka.jpg', 'Minuman jahe, serai, gula batu, dan kayu manis.'),
('beras-kencur', 'Es Beras Kencur', 'Jawa', 'minuman', 17000, 'Herbal segar', 'drink', 'assets/restoran/beras-kencur.jpeg', 'Jamu beras kencur dingin dengan rasa manis, wangi, dan menyegarkan.'),
('paket-nusantara', 'Paket Lengkap Nusantara', 'Pilihan chef', 'paket', 72000, 'Komplet', 'package', 'assets/restoran/paket-lengkap-nusantara.jpeg', 'Rendang mini, sate ayam, nasi liwet, sambal, lalapan, dan es cendol.');
