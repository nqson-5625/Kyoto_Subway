import psycopg

# Lấy chuỗi kết nối từ file .env của bạn
conn_str = "postgresql://kyosw:123456@localhost:5432/kyoto_subway"

try:
    # Thử thiết lập kết nối
    with psycopg.connect(conn_str) as conn:
        with conn.cursor() as cur:
            # Chạy một câu lệnh SQL cơ bản để kiểm tra
            cur.execute("SELECT version();")
            db_version = cur.fetchone()
            print("🚀 Kết nối DB thành công!")
            print(f"Phiên bản PostgreSQL: {db_version[0]}")
except Exception as e:
    print("❌ Kết nối thất bại. Lỗi chi tiết:")
    print(e)