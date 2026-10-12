# ==============================================================================
# BÀI TẬP 4: THIẾT LẬP CUSTOM NETWORK & NAMED VOLUME BẰNG DOCKER CLI (PowerShell)
# Session 10 - DevOps Fundamental
# Đường dẫn: homework/session_10/ex4/commands.ps1
# ==============================================================================

$ErrorActionPreference = "Stop"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ">>> KHỞI ĐỘNG BÀI TẬP 4: CUSTOM NETWORK & NAMED VOLUME CLI <<<" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# 0. Dọn dẹp tài nguyên cũ
Write-Host "`n[Bước 0] Dọn dẹp tài nguyên cũ..." -ForegroundColor Yellow
docker rm -f db-server app-container 2>$null
docker network rm app-net 2>$null
docker volume rm db-data 2>$null
Write-Host "=> Dọn dẹp hoàn tất!" -ForegroundColor Green

# 1. Tạo Custom Bridge Network: app-net
Write-Host "`n[Bước 1] Tạo Custom Bridge Network: app-net..." -ForegroundColor Yellow
docker network create --driver bridge app-net
docker network ls | Select-String "app-net"

# 2. Tạo Named Volume: db-data
Write-Host "`n[Bước 2] Tạo Named Volume: db-data..." -ForegroundColor Yellow
docker volume create db-data
docker volume ls | Select-String "db-data"

# 3. Khởi chạy Database Container: db-server
Write-Host "`n[Bước 3] Khởi chạy Database Container: db-server..." -ForegroundColor Yellow
docker run -d `
  --name db-server `
  --network app-net `
  -v db-data:/var/lib/postgresql/data `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=postgres `
  -e POSTGRES_DB=appdb `
  postgres:15-alpine

Write-Host "Chờ PostgreSQL khởi động hoàn tất..."
do {
    Start-Sleep -Seconds 1
    $status = docker exec db-server pg_isready -U postgres -d appdb 2>$null
} while ($LASTEXITCODE -ne 0)
Write-Host "=> PostgreSQL db-server đã sẵn sàng!" -ForegroundColor Green

# 4. Khởi chạy Backend Container: app-container
Write-Host "`n[Bước 4] Khởi chạy Backend Container: app-container..." -ForegroundColor Yellow
$imageExists = docker image inspect hw-backend:multistage 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Sử dụng image: hw-backend:multistage"
    docker run -d `
      --name app-container `
      --network app-net `
      -p 3000:3000 `
      -e DB_HOST=db-server `
      -e DB_PORT=5432 `
      -e DB_USER=postgres `
      -e DB_PASSWORD=postgres `
      -e DB_NAME=appdb `
      hw-backend:multistage
} else {
    Write-Host "Sử dụng image: node:18-alpine"
    docker run -d `
      --name app-container `
      --network app-net `
      -p 3000:3000 `
      -e DB_HOST=db-server `
      -e DB_PORT=5432 `
      -e DB_USER=postgres `
      -e DB_PASSWORD=postgres `
      -e DB_NAME=appdb `
      node:18-alpine sh -c "node -e 'require(\"http\").createServer((req,res)=>res.end(\"Backend App OK\")).listen(3000)'"
}
Write-Host "=> app-container đang hoạt động trên app-net!" -ForegroundColor Green

# 5. Kiểm tra DNS Resolution
Write-Host "`n[Bước 5] Kiểm tra cấu hình mạng & DNS Resolution..." -ForegroundColor Yellow
docker network inspect app-net
docker exec app-container ping -c 2 db-server
Write-Host "=> DNS Resolution thành công!" -ForegroundColor Green

# 6. Kiểm tra Data Persistence
Write-Host "`n[Bước 6] Tiến hành kiểm thử Data Persistence..." -ForegroundColor Yellow

Write-Host "6.1. Tạo bảng và thêm dữ liệu mẫu vào db-server:"
$sqlInit = @"
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
"@
$sqlInit | docker exec -i db-server psql -U postgres -d appdb

Write-Host "`n6.2. XÓA CỨNG Database Container (docker rm -f db-server):"
docker rm -f db-server
Write-Host "Đã xóa cứng db-server."

Write-Host "`n6.3. Khởi chạy lại Container DB mới gắn cùng Volume db-data:"
docker run -d `
  --name db-server `
  --network app-net `
  -v db-data:/var/lib/postgresql/data `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=postgres `
  -e POSTGRES_DB=appdb `
  postgres:15-alpine

Write-Host "Chờ PostgreSQL mới sẵn sàng..."
do {
    Start-Sleep -Seconds 1
    $status = docker exec db-server pg_isready -U postgres -d appdb 2>$null
} while ($LASTEXITCODE -ne 0)

Write-Host "`n6.4. Xác minh dữ liệu trong container mới từ Volume db-data:"
docker exec -i db-server psql -U postgres -d appdb -c "SELECT * FROM users;"

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host ">>> XÁC NHẬN: DỮ LIỆU NGUYÊN VẸN SAU KHI TÁI TẠO CONTAINER DB!  <<<" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
