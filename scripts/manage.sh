#!/usr/bin/env bash

# ==============================================================================
# Script quản trị MinIO Docker trên Linux/macOS (Bash)
# Hướng dẫn chạy: ./scripts/manage.sh <lệnh>
# ==============================================================================

# Màu sắc đầu ra
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0;37m' # No Color

# 1. Kiểm tra vị trí chạy script
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}[LỖI] Vui lòng chạy script này từ thư mục gốc của dự án (thư mục chứa docker-compose.yml).${NC}"
    echo -e "Ví dụ: ./scripts/manage.sh up"
    exit 1
fi

# 2. Load các biến môi trường từ file .env
if [ -f ".env" ]; then
    echo -e "Đang tải cấu hình từ file .env..."
    # Đọc từng dòng, bỏ qua dòng comment và dòng trống, xuất biến ra môi trường hiện tại
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${YELLOW}[CẢNH BÁO] Không tìm thấy file .env. Sẽ sử dụng cấu hình mặc định.${NC}"
fi

# Gán biến mặc định nếu trống
MINIO_API_PORT=${MINIO_API_PORT:-9000}
MINIO_CONSOLE_PORT=${MINIO_CONSOLE_PORT:-9001}
MINIO_VOLUMES=${MINIO_VOLUMES:-./data}
MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}

# Đường dẫn tuyệt đối thư mục dữ liệu
ABSOLUTE_VOLUME_PATH=$(realpath "${MINIO_VOLUMES}" 2>/dev/null || echo "${MINIO_VOLUMES}")

# 3. Hiển thị hướng dẫn nếu không truyền tham số
show_usage() {
    echo -e "Cách sử dụng: $0 [lệnh] [tùy chọn]"
    echo -e "Danh sách các lệnh:"
    echo -e "  up       : Khởi chạy các container MinIO ở chế độ background"
    echo -e "  down     : Dừng và xóa các container"
    echo -e "  restart  : Khởi động lại các container"
    echo -e "  logs     : Theo dõi logs của các container"
    echo -e "  status   : Kiểm tra trạng thái hoạt động các container"
    echo -e "  backup   : Sao lưu thư mục dữ liệu ($MINIO_VOLUMES) thành file nén .tar.gz"
    echo -e "  restore  : Khôi phục dữ liệu từ file backup (chỉ định file hoặc khôi phục file mới nhất)"
}

if [ -z "$1" ]; then
    show_usage
    exit 1
fi

ACTION=$1
BACKUP_FILE=$2

# 4. Xử lý các lệnh
case "$ACTION" in
    up)
        echo -e "${CYAN}--------------------------------------------------${NC}"
        echo -e "${CYAN}Khởi động dịch vụ MinIO trên Docker...${NC}"
        echo -e "${CYAN}--------------------------------------------------${NC}"
        docker compose up -d
        
        echo -e ""
        echo -e "${GREEN}==================================================${NC}"
        echo -e "${GREEN} Khởi động thành công!${NC}"
        echo -e "${GREEN} API Endpoint: http://localhost:${MINIO_API_PORT}${NC}"
        echo -e "${GREEN} Console UI:   http://localhost:${MINIO_CONSOLE_PORT}${NC}"
        echo -e "${GREEN} Tài khoản:    ${MINIO_ROOT_USER}${NC}"
        echo -e "${GREEN}==================================================${NC}"
        ;;
        
    down)
        echo -e "${YELLOW}Đang dừng các container MinIO...${NC}"
        docker compose down
        echo -e "${GREEN}Đã dừng và giải phóng tài nguyên thành công.${NC}"
        ;;
        
    restart)
        echo -e "${CYAN}Đang khởi động lại dịch vụ...${NC}"
        docker compose restart
        echo -e "${GREEN}Đã khởi động lại thành công.${NC}"
        ;;
        
    logs)
        echo -e "Đang theo dõi logs (nhấn Ctrl+C để thoát)..."
        docker compose logs -f
        ;;
        
    status)
        echo -e "${CYAN}Trạng thái các container của dự án:${NC}"
        docker compose ps
        ;;
        
    backup)
        mkdir -p backups
        TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
        TAR_FILE="backups/minio-backup-${TIMESTAMP}.tar.gz"
        
        echo -e "${CYAN}Đang tiến hành sao lưu dữ liệu...${NC}"
        echo -e "Thư mục nguồn: ${ABSOLUTE_VOLUME_PATH}"
        echo -e "File đích:     ${TAR_FILE}"
        
        if [ -d "${ABSOLUTE_VOLUME_PATH}" ]; then
            # Tạm thời dừng container MinIO để đảm bảo tính toàn vẹn dữ liệu
            echo -e "Đang tạm dừng container MinIO..."
            docker compose stop minio >/dev/null 2>&1
            
            # Thực hiện nén thư mục
            if tar -czf "${TAR_FILE}" -C "$(dirname "${ABSOLUTE_VOLUME_PATH}")" "$(basename "${ABSOLUTE_VOLUME_PATH}")"; then
                echo -e "${GREEN}Sao lưu dữ liệu thành công! File lưu tại: ${TAR_FILE}${NC}"
            else
                echo -e "${RED}[LỖI] Sao lưu thất bại.${NC}"
            fi
            
            # Khởi động lại container
            echo -e "Đang khởi động lại container MinIO..."
            docker compose start minio >/dev/null 2>&1
        else
            echo -e "${YELLOW}[CẢNH BÁO] Thư mục dữ liệu ${ABSOLUTE_VOLUME_PATH} chưa tồn tại hoặc rỗng.${NC}"
        fi
        ;;
        
    restore)
        # Nếu không truyền tên file, tự động tìm file mới nhất
        if [ -z "${BACKUP_FILE}" ]; then
            if [ -d "backups" ]; then
                LATEST_BACKUP=$(ls -t backups/*.tar.gz 2>/dev/null | head -n 1)
                if [ -n "${LATEST_BACKUP}" ]; then
                    BACKUP_FILE="${LATEST_BACKUP}"
                fi
            fi
        fi
        
        if [ -z "${BACKUP_FILE}" ] || [ ! -f "${BACKUP_FILE}" ]; then
            echo -e "${RED}[LỖI] Không tìm thấy file backup nào để khôi phục.${NC}"
            echo -e "Cú pháp: ./scripts/manage.sh restore [đường_dẫn_file_backup.tar.gz]"
            exit 1
        fi
        
        echo -e "${CYAN}Chuẩn bị khôi phục dữ liệu từ: ${BACKUP_FILE}${NC}"
        echo -e "Thư mục đích: ${ABSOLUTE_VOLUME_PATH}"
        
        read -p "CẢNH BÁO: Dữ liệu hiện tại trong ${ABSOLUTE_VOLUME_PATH} sẽ bị GHI ĐÈ hoàn toàn. Tiếp tục? (y/n): " CONFIRM
        if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
            echo -e "${YELLOW}Đã hủy quá trình khôi phục dữ liệu.${NC}"
            exit 0
        fi
        
        # Dừng container hoàn toàn trước khi restore
        echo -e "Đang dừng dịch vụ MinIO..."
        docker compose down >/dev/null 2>&1
        
        # Xóa dữ liệu cũ và tạo mới thư mục rỗng
        echo -e "Đang dọn dẹp thư mục dữ liệu cũ..."
        rm -rf "${ABSOLUTE_VOLUME_PATH:?}"/*
        mkdir -p "${ABSOLUTE_VOLUME_PATH}"
        
        # Tiến hành giải nén tar.gz
        echo -e "Đang giải nén dữ liệu từ backup..."
        # tar nén nguyên thư mục 'data', ta giải nén vào thư mục cha của 'data'
        PARENT_DIR=$(dirname "${ABSOLUTE_VOLUME_PATH}")
        if tar -xzf "${BACKUP_FILE}" -C "${PARENT_DIR}"; then
            echo -e "${GREEN}Khôi phục dữ liệu thành công!${NC}"
            echo -e "Đang khởi động lại dịch vụ MinIO..."
            docker compose up -d
        else
            echo -e "${RED}[LỖI] Giải nén backup thất bại.${NC}"
        fi
        ;;
        
    *)
        echo -e "${RED}[LỖI] Lệnh không hợp lệ: $ACTION${NC}"
        show_usage
        exit 1
        ;;
esac
