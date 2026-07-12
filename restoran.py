import json
import sqlite3
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


HOST = "127.0.0.1"
PORT = 8001
APP_FILE = "restoran.html"
DB_FILE = Path("restoran.db")
SCHEMA_FILE = Path("restoran.sql")

MENU_SEEDS = [
    ("rendang", "Rendang Daging", "Sumatera Barat", "makanan", 42000, "Pedas gurih", "rendang", "assets/restoran/rendang-daging.jpg", "Daging sapi empuk dimasak perlahan dengan santan, cabai, dan rempah Minang."),
    ("sate", "Sate Ayam Madura", "Madura", "makanan", 32000, "Manis pedas", "sate", "assets/restoran/sate-ayam-madura.webp", "Sate ayam bakar arang dengan bumbu kacang, kecap, lontong, dan acar."),
    ("rawon", "Rawon Surabaya", "Jawa Timur", "makanan", 38000, "Hangat rempah", "soup", "assets/restoran/rawon-surabaya.jpg", "Sup daging kuah kluwek berwarna hitam dengan tauge pendek dan telur asin."),
    ("gudeg", "Gudeg Jogja", "Yogyakarta", "makanan", 35000, "Manis legit", "rice", "assets/restoran/gudeg-jogja.jpg", "Nangka muda, ayam opor, telur pindang, krecek, dan nasi hangat."),
    ("soto", "Soto Betawi", "Jakarta", "makanan", 40000, "Gurih santan", "soup", "assets/restoran/soto-betawi.jpg", "Kuah santan susu dengan daging sapi, kentang, tomat, dan emping."),
    ("nasi-liwet", "Nasi Liwet Solo", "Jawa Tengah", "makanan", 34000, "Gurih lembut", "rice", "assets/restoran/nasi-liwet-solo.jpg", "Nasi gurih, suwiran ayam, sayur labu, telur, dan areh santan."),
    ("ayam-taliwang", "Ayam Taliwang", "Lombok", "makanan", 45000, "Pedas kuat", "chicken", "assets/restoran/ayam-taliwang.jpg", "Ayam bakar bumbu cabai Lombok dengan plecing kangkung dan nasi putih."),
    ("pempek", "Pempek Kapal Selam", "Palembang", "makanan", 30000, "Asam pedas", "snack", "assets/restoran/pempek-kapal-selam.jpg", "Pempek isi telur dengan kuah cuko, timun, dan mi kuning."),
    ("cendol", "Es Cendol Dawet", "Jawa", "minuman", 18000, "Segar manis", "drink", "assets/restoran/es-cendol-dawet.jpg", "Cendol pandan, santan, gula aren cair, dan es serut."),
    ("wedang", "Wedang Jahe", "Nusantara", "minuman", 16000, "Hangat", "tea", "assets/restoran/es_cendol_nangka.jpg", "Minuman jahe, serai, gula batu, dan kayu manis."),
    ("beras-kencur", "Es Beras Kencur", "Jawa", "minuman", 17000, "Herbal segar", "drink", "assets/restoran/beras-kencur.jpeg", "Jamu beras kencur dingin dengan rasa manis, wangi, dan menyegarkan."),
    ("paket-nusantara", "Paket Lengkap Nusantara", "Pilihan chef", "paket", 72000, "Komplet", "package", "assets/restoran/paket-lengkap-nusantara.jpeg", "Rendang mini, sate ayam, nasi liwet, sambal, lalapan, dan es cendol."),
]


def get_connection():
    connection = sqlite3.connect(DB_FILE)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    return connection


def init_database():
    if not SCHEMA_FILE.exists():
        raise SystemExit(f"File SQL tidak ditemukan: {SCHEMA_FILE}")

    with get_connection() as db:
        db.executescript(SCHEMA_FILE.read_text(encoding="utf-8"))
        existing_order_columns = {
            row["name"] for row in db.execute("PRAGMA table_info(orders)").fetchall()
        }
        if "payment_method" not in existing_order_columns:
            db.execute("ALTER TABLE orders ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'cash'")
        if "booking_id" not in existing_order_columns:
            db.execute("ALTER TABLE orders ADD COLUMN booking_id INTEGER")
        db.executemany(
            """
            INSERT INTO menus
            (id, name, origin, category, price, spice, icon, image, description)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                origin = excluded.origin,
                category = excluded.category,
                price = excluded.price,
                spice = excluded.spice,
                icon = excluded.icon,
                image = excluded.image,
                description = excluded.description
            """,
            MENU_SEEDS,
        )


def read_json(handler):
    length = int(handler.headers.get("Content-Length", "0"))
    if length == 0:
        return {}
    body = handler.rfile.read(length).decode("utf-8")
    return json.loads(body)


def normalize_order(row):
    order = dict(row)
    order.setdefault("payment_method", "cash")
    return order


def normalize_booking(row):
    booking = dict(row)
    booking.setdefault("status", "booked")
    return booking


def menu_rows():
    with get_connection() as db:
        rows = db.execute(
            """
            SELECT id, name, origin, category, price, spice, icon, image, description
            FROM menus
            ORDER BY
                CASE category
                    WHEN 'makanan' THEN 1
                    WHEN 'minuman' THEN 2
                    WHEN 'paket' THEN 3
                    ELSE 4
                END,
                name
            """
        ).fetchall()
        return [dict(row) for row in rows]


def booking_rows():
    with get_connection() as db:
        rows = db.execute(
            """
            SELECT id, customer_name, phone, email, guests, booking_date, booking_time, occasion, note, status, created_at
            FROM bookings
            ORDER BY id DESC
            LIMIT 20
            """
        ).fetchall()
        return [normalize_booking(row) for row in rows]


def create_booking(payload):
    customer_name = str(payload.get("customer_name", "")).strip()
    phone = str(payload.get("phone", "")).strip()
    email = str(payload.get("email", "")).strip()
    guests = int(payload.get("guests", 0))
    booking_date = str(payload.get("booking_date", "")).strip()
    booking_time = str(payload.get("booking_time", "")).strip()
    occasion = str(payload.get("occasion", "")).strip() or "Makan santai"
    note = str(payload.get("note", "")).strip()

    if not customer_name or not phone or guests <= 0 or not booking_date or not booking_time:
        raise ValueError("Data booking belum lengkap.")

    with get_connection() as db:
        cursor = db.execute(
            """
            INSERT INTO bookings
            (customer_name, phone, email, guests, booking_date, booking_time, occasion, note, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'booked')
            """,
            (customer_name, phone, email, guests, booking_date, booking_time, occasion, note),
        )
        booking_id = cursor.lastrowid
        row = db.execute(
            """
            SELECT id, customer_name, phone, email, guests, booking_date, booking_time, occasion, note, status, created_at
            FROM bookings
            WHERE id = ?
            """,
            (booking_id,),
        ).fetchone()
        return normalize_booking(row)


def create_order(payload):
    items = payload.get("items", [])
    if not items:
        raise ValueError("Pesanan masih kosong.")

    payment_method = str(payload.get("payment_method", "cash")).strip().lower() or "cash"
    if payment_method not in {"cash", "qris", "debit"}:
        raise ValueError("Metode pembayaran tidak valid.")

    booking_id = payload.get("booking_id")
    booking_id = int(booking_id) if booking_id not in (None, "", "null") else None

    quantities = {}
    for item in items:
        menu_id = str(item.get("id", "")).strip()
        quantity = int(item.get("quantity", 0))
        if menu_id and quantity > 0:
            quantities[menu_id] = quantities.get(menu_id, 0) + quantity

    if not quantities:
        raise ValueError("Jumlah menu tidak valid.")

    with get_connection() as db:
        if booking_id is not None:
            booking_exists = db.execute("SELECT id FROM bookings WHERE id = ?", (booking_id,)).fetchone()
            if booking_exists is None:
                raise ValueError("Booking tidak ditemukan.")

        placeholders = ",".join("?" for _ in quantities)
        menus = db.execute(
            f"SELECT id, name, price FROM menus WHERE id IN ({placeholders})",
            list(quantities.keys()),
        ).fetchall()

        if len(menus) != len(quantities):
            raise ValueError("Ada menu yang tidak ditemukan di database.")

        order_items = []
        total = 0
        for menu in menus:
            quantity = quantities[menu["id"]]
            subtotal = menu["price"] * quantity
            total += subtotal
            order_items.append((menu["id"], menu["name"], menu["price"], quantity, subtotal))

        cursor = db.execute(
            "INSERT INTO orders (total, payment_method, booking_id) VALUES (?, ?, ?)",
            (total, payment_method, booking_id),
        )
        order_id = cursor.lastrowid
        db.executemany(
            """
            INSERT INTO order_items
            (order_id, menu_id, menu_name, price, quantity, subtotal)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [(order_id, *item) for item in order_items],
        )

        return {"id": order_id, "total": total, "items": len(order_items), "payment_method": payment_method}


def recent_orders():
    with get_connection() as db:
        orders = db.execute(
            """
            SELECT
                o.id,
                o.total,
                o.payment_method,
                o.created_at,
                o.booking_id,
                b.customer_name AS booking_name,
                b.booking_date,
                b.booking_time
            FROM orders o
            LEFT JOIN bookings b ON b.id = o.booking_id
            ORDER BY o.id DESC
            LIMIT 20
            """
        ).fetchall()
        results = []
        for order in orders:
            items = db.execute(
                """
                SELECT menu_id, menu_name, price, quantity, subtotal
                FROM order_items
                WHERE order_id = ?
                ORDER BY id
                """,
                (order["id"],),
            ).fetchall()
            payload = normalize_order(order)
            payload["items"] = [dict(item) for item in items]
            results.append(payload)
        return results


class RestaurantHandler(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        super().end_headers()

    def send_json(self, payload, status=200):
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/api/menus":
            self.send_json({"menus": menu_rows()})
            return
        if path == "/api/orders":
            self.send_json({"orders": recent_orders()})
            return
        if path == "/api/bookings":
            self.send_json({"bookings": booking_rows()})
            return
        super().do_GET()

    def do_POST(self):
        path = urlparse(self.path).path
        try:
            if path == "/api/orders":
                result = create_order(read_json(self))
                self.send_json({"message": "Pesanan tersimpan ke database.", "order": result}, status=201)
                return
            if path == "/api/bookings":
                result = create_booking(read_json(self))
                self.send_json({"message": "Booking tersimpan ke database.", "booking": result}, status=201)
                return
        except (ValueError, TypeError, json.JSONDecodeError) as error:
            self.send_json({"error": str(error)}, status=400)
            return

        self.send_error(404, "Endpoint tidak ditemukan")


def main():
    init_database()
    server = ThreadingHTTPServer((HOST, PORT), RestaurantHandler)
    print(f"Website restoran siap: http://{HOST}:{PORT}/{APP_FILE}")
    print(f"Database: {DB_FILE.resolve()}")
    print("Tekan Ctrl+C untuk berhenti.")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer dihentikan.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
