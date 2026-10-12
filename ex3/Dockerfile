# ==============================================================
# Stage 1: Build stage (Dependencies & Cache Optimization)
# Image alias: builder
# Base image: node:18-alpine (Môi trường chuẩn bị và cài đặt dependencies)
# ==============================================================
FROM node:18-alpine AS builder

WORKDIR /app

# 1. Tận dụng triệt để Docker Layer Caching:
# Copy tệp khai báo phụ thuộc trước. Khi chỉ sửa đổi source code mà không thêm package mới,
# Docker sẽ tái sử dụng cache của bước npm install mà không cần tải lại từ mạng.
COPY package*.json ./

# 2. Cài đặt các dependencies cần thiết cho production và dọn sạch npm cache
RUN npm ci --only=production || npm install --omit=dev && npm cache clean --force

# 3. Copy mã nguồn vào stage builder
COPY . .

# ==============================================================
# Stage 2: Runtime stage (Siêu nhẹ phục vụ Production)
# Target Image: hw-backend:multistage
# Base image: node:18-alpine (Alpine Linux siêu tinh gọn)
# ==============================================================
FROM node:18-alpine

WORKDIR /app

# Thiết lập biến môi trường chuẩn Production
ENV NODE_ENV=production \
    PORT=3000

# Áp dụng chuẩn bảo mật: Chạy với user non-root 'node' có sẵn trong Alpine
USER node

# Chỉ trích xuất tệp sản phẩm và node_modules từ stage builder
# Sử dụng --chown=node:node để đảm bảo user node có quyền sở hữu hợp lệ
COPY --chown=node:node --from=builder /app/package*.json ./
COPY --chown=node:node --from=builder /app/node_modules ./node_modules
COPY --chown=node:node --from=builder /app/server.js ./

# Khai báo port lắng nghe của ứng dụng backend
EXPOSE 3000

# Cấu hình Healthcheck để Docker chủ động giám sát trạng thái container
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

# Lệnh khởi chạy ứng dụng
CMD ["node", "server.js"]
