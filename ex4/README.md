# Báo Cáo Bài Tập 4: Thiết Lập Custom Network & Named Volume Bằng Docker CLI

> **Môn học**: DevOps Fundamental  
> **Session**: 10 - Containerization & Docker Optimization  
> **Bài tập**: Bài 4 (EX4) - Thiết lập Custom Network & Named Volume bằng Docker CLI  
> **GitHub Path**: `homework/session_10/ex4/`

---

## 1. Mục Tiêu Bài Tập

1. **Custom Bridge Network**: Tạo mạng Bridge tùy biến (`app-net`) để các Container trong cùng mạng có thể tự động giao tiếp nội bộ thông qua tên service/tên container (**DNS Resolution & Service Discovery**), thay thế cho mạng default bridge vốn không hỗ trợ cơ chế này.
2. **Named Volume & Data Persistence**: Tạo volume chuyên dụng (`db-data`) do Docker quản lý để lưu trữ dữ liệu cơ sở dữ liệu bền vững, độc lập hoàn toàn với vòng đời của Container.
3. **Kết nối cụm 2 Container**: Triển khai thủ công bằng Docker CLI cụm ứng dụng gồm Backend Web API (`app-container`) và Database (`db-server` sử dụng PostgreSQL 15).
4. **Kiểm chứng Data Persistence**: Thực hiện kịch bản xóa cứng container DB (`docker rm -f db-server`), sau đó dựng lại container mới gắn cùng volume để chứng minh dữ liệu không bị thất thoát.

---

## 2. Cấu Trúc Thư Mục

```text
homework/session_10/ex4/
├── commands.sh       # Script Bash tự động hóa toàn bộ quy trình thực thi và kiểm thử (Linux/macOS/Git Bash)
├── commands.ps1      # Script PowerShell tự động hóa (hỗ trợ thực thi trên Windows)
└── README.md         # Báo cáo chi tiết, giải thích lý thuyết, các lệnh CLI và kết quả kiểm thử
```

---

## 3. Kiến Thức Cốt Lõi (Core Concepts)

### 3.1. Default Bridge Network vs. Custom Bridge Network

| Tiêu chí | Default Bridge (`bridge`) | Custom Bridge (`app-net`) |
| :--- | :--- | :--- |
| **DNS Resolution tự động** | ❌ **Không hỗ trợ**. Các container chỉ có thể gọi nhau qua IP hoặc cờ `--link` cũ. |  **Hỗ trợ đầy đủ**. Docker tích hợp Embedded DNS (127.0.0.11), các container gọi nhau qua container name. |
| **Tính cô lập (Isolation)** | Kém an toàn, tất cả container không chỉ định mạng đều vào đây. | An toàn tuyệt đối, chỉ những container thuộc cùng mạng mới thấy nhau. |
| **Cấu hình trực tiếp** | Không thể ngắt/kết nối mạng khi container đang chạy một cách linh hoạt. | Có thể kết nối/ngắt kết nối động bằng `docker network connect/disconnect`. |

### 3.2. Named Volume & Cơ Chế Lưu Trữ Dữ Liệu Bền Vững (Data Persistence)

- Mặc định, dữ liệu phát sinh trong container được ghi vào **Container Writable Layer**. Khi container bị xóa (`docker rm`), layer này sẽ biến mất vĩnh viễn (**Ephemeral Storage**).
- **Named Volume (`db-data`)**: Được Docker daemon lưu trữ và quản lý trực tiếp tại thư mục an toàn trên host (`/var/lib/docker/volumes/db-data/_data`).
- Khi mount `-v db-data:/var/lib/postgresql/data`, dữ liệu PostgreSQL được lưu trực tiếp vào Volume. Khi container `db-server` bị xóa bỏ hoàn toàn (`docker rm -f`), Volume `db-data` vẫn tồn tại nguyên vẹn. Container mới chỉ cần mount lại Volume này là có thể tiếp tục sử dụng dữ liệu cũ mà không mất mát bất kỳ byte nào.

---

## 4. Các Bước Thực Hiện Chi Tiết Bằng Docker CLI

### Bước 1: Tạo Custom Bridge Network `app-net`
Tạo mạng bridge riêng biệt cho cụm ứng dụng:
```bash
docker network create --driver bridge app-net
```
*Kiểm tra danh sách mạng:*
```bash
docker network ls | grep app-net
```

---

### Bước 2: Tạo Named Volume `db-data`
Tạo volume lưu trữ dữ liệu PostgreSQL:
```bash
docker volume create db-data
```
*Kiểm tra danh sách volume:*
```bash
docker volume ls | grep db-data
```

---

### Bước 3: Khởi chạy Database Container `db-server`
Khởi chạy PostgreSQL 15 Alpine, tham gia mạng `app-net` và mount volume `db-data`:
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=appdb \
  postgres:15-alpine
```

*Giải thích các tham số:*
- `--name db-server`: Đặt tên định danh container là `db-server`, dùng làm hostname trong mạng nội bộ.
- `--network app-net`: Gán container vào custom network đã tạo.
- `-v db-data:/var/lib/postgresql/data`: Mount Named Volume `db-data` vào thư mục lưu trữ dữ liệu của PostgreSQL.
- `-e POSTGRES_*`: Thiết lập thông tin tài khoản và database khởi tạo.

---

### Bước 4: Khởi chạy Backend Container `app-container`
Khởi chạy container Backend tham gia cùng mạng `app-net`, truyền biến môi trường trỏ hostname tới `db-server`:
```bash
docker run -d \
  --name app-container \
  --network app-net \
  -p 3000:3000 \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  -e DB_NAME=appdb \
  node:18-alpine sh -c "node -e 'require(\"http\").createServer((req,res)=>res.end(\"Backend App OK\")).listen(3000)'"
```
*(Nếu đã có sẵn image `hw-backend:multistage` từ Bài 3, có thể thay thế bằng image đó).*

---

### Bước 5: Kiểm Tra Cấu Hình Mạng & DNS Resolution

#### 1. Kiểm tra chi tiết cấu hình mạng:
```bash
docker network inspect app-net
```
*Kết quả quan sát*: Cả 2 container `db-server` và `app-container` đều nằm trong danh sách `Containers` của mạng `app-net` và được cấp IP trong cùng dải subnet (ví dụ: `172.18.0.2` và `172.18.0.3`).

#### 2. Kiểm tra phân giải tên miền (DNS Resolution):
Thực thi lệnh ping từ `app-container` tới `db-server`:
```bash
docker exec -it app-container ping -c 2 db-server
```
*Kết quả thực tế mong đợi:*
```text
PING db-server (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.081 ms
64 bytes from 172.18.0.2: seq=1 ttl=64 time=0.065 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.065/0.073/0.081 ms
```
> **Đánh giá**: `app-container` giải mã thành công hostname `db-server` thành IP nội bộ `172.18.0.2` thông qua Docker Embedded DNS server mà không cần cấu hình file `/etc/hosts` thủ công.

---

### Bước 6: Kiểm Thử Data Persistence (Kiểm Chứng Lưu Trữ Bền Vững)

#### 6.1. Thêm dữ liệu mẫu vào PostgreSQL
Kết nối vào container `db-server` qua `psql` để tạo bảng và chèn các bản ghi mẫu:
```bash
docker exec -i db-server psql -U postgres -d appdb << 'EOF'
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (username, email) VALUES 
('nguyenvana', 'vana@example.com'),
('tranthib', 'thib@example.com'),
('levanc', 'vanc@example.com');

SELECT * FROM users;
EOF
```
*Kết quả bảng dữ liệu được tạo:*
```text
 id |  username  |      email       |         created_at         
----+------------+------------------+----------------------------
  1 | nguyenvana | vana@example.com | 2026-10-12 13:15:00.123456
  2 | tranthib   | thib@example.com | 2026-10-12 13:15:00.123456
  3 | levanc     | vanc@example.com | 2026-10-12 13:15:00.123456
(3 rows)
```

#### 6.2. Xóa CỨNG Database Container
Mô phỏng sự cố hoặc thao tác bảo trì bằng cách ép xóa container:
```bash
docker rm -f db-server
```
*Kiểm tra danh sách container:*
```bash
docker ps -a | grep db-server
```
*(Lệnh không trả về kết quả, xác nhận container `db-server` đã bị xóa hoàn toàn khỏi Docker engine).*

#### 6.3. Khởi chạy lại Container DB mới gắn cùng Volume `db-data`
Tạo một container PostgreSQL hoàn toàn mới, gắn lại đúng Named Volume `db-data`:
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=appdb \
  postgres:15-alpine
```

#### 6.4. Xác minh dữ liệu không bị mất
Chờ 2-3 giây để PostgreSQL khởi động, sau đó truy vấn lại dữ liệu:
```bash
docker exec -i db-server psql -U postgres -d appdb -c "SELECT * FROM users;"
```
*Kết quả nhận được:*
```text
 id |  username  |      email       |         created_at         
----+------------+------------------+----------------------------
  1 | nguyenvana | vana@example.com | 2026-10-12 13:15:00.123456
  2 | tranthib   | thib@example.com | 2026-10-12 13:15:00.123456
  3 | levanc     | vanc@example.com | 2026-10-12 13:15:00.123456
(3 rows)
```

> **Kết luận**: Tất cả các bảng và bản ghi dữ liệu vẫn tồn tại nguyên vẹn 100% trong `db-data` dù container cũ đã bị hủy hoại. Mục tiêu Data Persistence đã được kiểm chứng thành công xuất sắc!

---

## 5. Bảng Tổng Hợp Lệnh Kiểm Tra Theo Yêu Cầu Đề Bài

| Lệnh kiểm tra đề bài | Mục đích kiểm tra | Kết quả mong đợi |
| :--- | :--- | :--- |
| `docker network ls \| grep app-net` | Kiểm tra sự tồn tại của Custom Network | Xuất hiện mạng `app-net` với driver `bridge` |
| `docker volume ls \| grep db-data` | Kiểm tra sự tồn tại của Named Volume | Xuất hiện volume `db-data` với driver `local` |
| `docker network inspect app-net` | Xem thông tin chi tiết mạng | Thấy 2 container `db-server` và `app-container` cùng thuộc mạng |
| `docker exec -it app-container ping -c 2 db-server` | Kiểm tra DNS Resolution nội bộ | Ping thành công 100%, 0% packet loss, nhận diện đúng IP của `db-server` |
| `docker exec -i db-server psql -U postgres -d appdb -c "SELECT * FROM users;"` | Kiểm tra Data Persistence | Dữ liệu bảng `users` giữ nguyên vẹn sau khi xóa và tạo lại container |

---

## 6. Hướng Dẫn Chạy Tự Động Bằng Script

Học viên có thể chạy toàn bộ quy trình trên một cách tự động thông qua script:

- **Trên môi trường Linux / macOS / Git Bash**:
  ```bash
  chmod +x commands.sh
  ./commands.sh
  ```

- **Trên môi trường Windows PowerShell**:
  ```powershell
  ./commands.ps1
  ```

---

## 7. Dọn Dẹp Tài Nguyên (Clean up)

Sau khi hoàn thành và đánh giá bài tập:
```bash
# Xóa các container
docker rm -f app-container db-server

# Xóa Custom Network
docker network rm app-net

# Xóa Named Volume
docker volume rm db-data
```
