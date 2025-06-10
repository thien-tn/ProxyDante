#!/usr/bin/env bash

# lib/common.sh
#
# Chứa các hàm dùng chung cho toàn bộ hệ thống
# Tác giả: akmaslov-dev
# Chỉnh sửa bởi: ThienTranJP

# Biến toàn cục
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
CONFIG_DIR="$SCRIPT_DIR/config"
LIB_DIR="$SCRIPT_DIR/lib"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Màu sắc cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hàm hiển thị thông báo thành công
# $1: Nội dung thông báo
success_message() {
    echo -e "${GREEN}[✓] $1${NC}"
}

# Hàm hiển thị thông báo lỗi
# $1: Nội dung thông báo
error_message() {
    echo -e "${RED}[✗] $1${NC}"
}

# Hàm hiển thị thông báo cảnh báo
# $1: Nội dung thông báo
warning_message() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Hàm hiển thị thông báo thông tin
# $1: Nội dung thông báo
info_message() {
    echo -e "${BLUE}[i] $1${NC}"
}

# Hàm tạm dừng cho đến khi người dùng nhấn Enter
pause() {
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}

# Hàm kiểm tra xem Dante đã được cài đặt chưa
is_dante_installed() {
    [[ -e /etc/sockd.conf ]] && return 0 || return 1
}

# Hàm lấy danh sách proxy user
get_proxy_users() {
    awk -F: '$3 > 1000 && $7 == "/usr/sbin/nologin" && $1 != "nobody" {print $1}' /etc/passwd
}

# Hàm kiểm tra xem user có tồn tại không
# $1: Tên user cần kiểm tra
user_exists() {
    getent passwd "$1" > /dev/null 2>&1
}

# Hàm tạo chuỗi ngẫu nhiên
# $1: Độ dài chuỗi (mặc định là 8)
generate_random_string() {
    local length=${1:-8}
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w "$length" | head -n 1
}

# Hàm lấy địa chỉ IP của máy chủ
get_server_ip() {
    hostname -I | awk '{print $1}'
}

# Hàm lấy port từ file cấu hình
get_dante_port() {
    if [[ -f /etc/sockd.conf ]]; then
        grep -oP 'internal:.*port\s*=\s*\K[0-9]+' /etc/sockd.conf
    else
        echo "1080" # Mặc định nếu không tìm thấy
    fi
}

# Hàm kiểm tra input là số hợp lệ
# $1: Giá trị cần kiểm tra
# $2: Giá trị nhỏ nhất (tùy chọn)
# $3: Giá trị lớn nhất (tùy chọn)
is_valid_number() {
    local value=$1
    local min=${2:-0}
    local max=${3:-999999}
    
    if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge "$min" ] && [ "$value" -le "$max" ]; then
        return 0
    else
        return 1
    fi
}

# Hàm kiểm tra cổng hợp lệ
# $1: Cổng cần kiểm tra
is_valid_port() {
    local port=$1
    
    # Kiểm tra cổng có phải là số nguyên dương và nằm trong khoảng hợp lệ (1-65535)
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Hàm kiểm tra cổng đã được sử dụng chưa
# $1: Cổng cần kiểm tra
is_port_in_use() {
    local port=$1
    
    # Kiểm tra cổng có đang được sử dụng không
    if command -v ss >/dev/null 2>&1; then
        # Sử dụng ss nếu có
        if ss -tuln | grep -q ":$port "; then
            return 0
        fi
    elif command -v netstat >/dev/null 2>&1; then
        # Sử dụng netstat nếu không có ss
        if netstat -tuln | grep -q ":$port "; then
            return 0
        fi
    else
        # Nếu không có công cụ nào, giả định cổng không được sử dụng
        warning_message "Không thể kiểm tra cổng đã được sử dụng chưa. Giả định cổng không được sử dụng."
        return 1
    fi
    
    return 1
}

# Hàm kiểm tra và mở cổng trong tường lửa
# $1: Số cổng cần mở
open_firewall_port() {
    local port=$1
    
    # Kiểm tra và mở cổng với UFW
    if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -q "Status: active"; then
        sudo ufw allow "$port"/tcp
        success_message "Đã mở cổng $port trong UFW."
    fi
    
    # Kiểm tra và mở cổng với iptables
    if command -v iptables >/dev/null 2>&1; then
        if ! sudo iptables -L | grep -q "ACCEPT.*tcp.*dpt:$port"; then
            sudo iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
            success_message "Đã mở cổng $port trong iptables."
        fi
    fi
}
