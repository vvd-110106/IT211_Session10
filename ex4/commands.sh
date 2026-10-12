#!/bin/bash
# ==============================================================================
# BÀI TẬP 4: THIẾT LẬP CUSTOM NETWORK & NAMED VOLUME BẰNG DOCKER CLI
# Session 10 - DevOps Fundamental
# Đường dẫn: homework/session_10/ex4/commands.sh
# ==============================================================================

set -e

# Định nghĩa màu sắc hiển thị
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}>>> KHỞI ĐỘNG BÀI TẬP 4: CUSTOM NETWORK & NAMED VOLUME CLI <<<${NC}"
echo -e "${BLUE}================================================================${NC}"

# ------------------------------------------------------------------------------
# 0. Dọn dẹp tài nguyên cũ nếu tồn tại
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[Bước 0] Dọn dẹp các tài nguyên cũ (nếu có)...${NC}"
docker rm -f db-server app-container 2>/dev/null || true
docker network rm app-net 2>/dev/null || true
docker volume rm db-data 2>/dev/null || true
echo -e "${GREEN}=> Dọn dẹp môi trường sạch sẽ!${NC}"

# ------------------------------------------------------------------------------
# 1. Tạo Custom Bridge Network tên 'app-net'
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[Bước 1] Tạo Custom Bridge Network: app-net...${NC}"
docker network create --driver bridge app-net

echo -e "${GREEN}=> Kiểm tra danh sách Network:${NC}"
docker network ls | grep app-net

# ------------------------------------------------------------------------------
# 2. Tạo Named Volume tên 'db-data'
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[Bước 2] Tạo Named Volume: db-data...${NC}"
docker volume create db-data

echo -e "${GREEN}=> Kiểm tra danh sách Volume:${NC}"
docker volume ls | grep db-data

# ------------------------------------------------------------------------------
# 3. Khởi chạy Database Container (postgres:15-alpine) tên 'db-server'
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[Bước 3] Khởi chạy Database Container: db-server...${NC}"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=appdb \
  postgres:15-alpine

echo -e "Đang chờ PostgreSQL khởi động hoàn tất..."
until docker exec db-server pg_isready -U postgres -d appdb >/dev/null 2>&1; do
  sleep 1
done
echo -e "${GREEN}=> PostgreSQL db-server đã sẵn sàng nhận kết nối!${NC}"

# ------------------------------------------------------------------------------
# 4. Khởi chạy Backend Container tên 'app-container' tham gia 'app-net'
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[Bước 4] Khởi chạy Backend Container: app-container...${NC}"
# Sử dụng image hw-backend:multistage nếu đã có sẵn, hoặc fallback node:18-alpine
if docker image inspect hw-backend:multistage >/dev/null 2>&1; then
  echo "Sử dụng image đã build: hw-backend:multistage"
  docker run -d \
    --name app-container \
    --network app-net \
    -p 3000:3000 \
    -e DB_HOST=db-server \
    -e DB_PORT=5432 \
    -e DB_USER=postgres \
    -e DB_PASSWORD=postgres \
    -e DB_NAME=appdb \
    hw-backend:multistage
else
  echo "Khởi chạy app-container bằng image node:18-alpine..."
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
fi
echo -e "${GREEN}=> app-container đang hoạt động trên mạng app-net!${NC}"

# ------------------------------------------------------------------------------
# 5. Kiểm tra DNS Resolution qua Custom Bridge Network
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[Bước 5] Kiểm tra cấu hình mạng & DNS Resolution...${NC}"
echo -e "--- Inspect Network app-net ---"
docker network inspect app-net

echo -e "\n--- Kiểm tra Ping từ app-container tới hostname db-server ---"
docker exec app-container ping -c 2 db-server
echo -e "${GREEN}=> DNS Resolution thành công: app-container đã giải mã IP và ping được db-server!${NC}"

# ------------------------------------------------------------------------------
# 6. Kiểm tra Data Persistence (Lưu trữ dữ liệu bền vững)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[Bước 6] Tiến hành kiểm thử Data Persistence...${NC}"

echo -e "6.1. Tạo bảng và thêm dữ liệu mẫu vào PostgreSQL db-server:"
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

echo -e "\n6.2. XÓA CỨNG Database Container (docker rm -f db-server):"
docker rm -f db-server
echo -e "Đã xóa hoàn toàn container db-server."

echo -e "\n6.3. Khởi chạy lại Container DB mới gắn cùng Volume db-data:"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=appdb \
  postgres:15-alpine

echo -e "Đang chờ PostgreSQL mới khởi động hoàn tất..."
until docker exec db-server pg_isready -U postgres -d appdb >/dev/null 2>&1; do
  sleep 1
done

echo -e "\n6.4. Xác minh dữ liệu trong container mới từ Volume db-data:"
docker exec -i db-server psql -U postgres -d appdb -c "SELECT * FROM users;"

echo -e "\n${GREEN}================================================================${NC}"
echo -e "${GREEN}>>> XÁC NHẬN: DỮ LIỆU HOÀN TOÀN NGUYÊN VẸN SAU KHI TÁI TẠO DB! <<<${NC}"
echo -e "${GREEN}>>> BÀI TẬP 4 HOÀN THÀNH XUẤT SẮC!                             <<<${NC}"
echo -e "${GREEN}================================================================${NC}"
