#!/usr/bin/env bash

# lib/check_environment.sh
#
# Chứa các hàm kiểm tra môi trường trước khi cài đặt
# Tác giả: akmaslov-dev
# Chỉnh sửa bởi: ThienTranJP

# Kiểm tra quyền root
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error_message "Script này cần được chạy với quyền root"
        exit 2
    fi
    success_message "Đang chạy với quyền root"
}

# Kiểm tra shell bash
check_bash() {
    if readlink /proc/$$/exe | grep -qs "dash"; then
        error_message "Script này cần được chạy với bash, không phải sh"
        exit 1
    fi
    success_message "Đang sử dụng bash shell"
}

# Phát hiện hệ điều hành
detect_os() {
    if [[ -e /etc/debian_version ]]; then
        # Sử dụng "deb" để tương thích với cả Debian và Ubuntu
        export OStype="deb"
        success_message "Phát hiện hệ điều hành: Debian/Ubuntu"
    elif [[ -e /etc/centos-release || -e /etc/redhat-release ]]; then
        export OStype="centos"
        success_message "Phát hiện hệ điều hành: CentOS/RHEL"
    else
        error_message "Script này chỉ hỗ trợ Debian, Ubuntu hoặc CentOS"
        exit 3
    fi
}

# Alias cho get_server_ip (tương thích ngược)
get_ip() {
    hostname -I | awk '{print $1}'
}

# Phát hiện giao diện mạng
detect_network_interface() {
    export interface="$(ip -o -4 route show to default | awk '{print $5}')"
    
    # Kiểm tra xem giao diện có tồn tại không
    if [[ -n "$interface" && -d "/sys/class/net/$interface" ]]; then
        success_message "Phát hiện giao diện mạng: $interface"
    else
        error_message "Không thể phát hiện giao diện mạng"
        exit 4
    fi
    
    # Lấy địa chỉ IP
    export hostname=$(hostname -I | awk '{print $1}')
    success_message "Địa chỉ IP máy chủ: $hostname"
}

# Kiểm tra các gói phụ thuộc cần thiết
check_dependencies() {
    local dependencies=("openssl" "make" "gcc")
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        warning_message "Các gói phụ thuộc sau chưa được cài đặt: ${missing_deps[*]}"
        info_message "Sẽ cài đặt các gói còn thiếu trong quá trình cài đặt"
    else
        success_message "Tất cả các gói phụ thuộc đã được cài đặt"
    fi
}

# Kiểm tra cổng đã được sử dụng chưa
# $1: Số cổng cần kiểm tra
is_port_in_use() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        return 0 # Cổng đã được sử dụng
    else
        return 1 # Cổng chưa được sử dụng
    fi
}

# Kiểm tra môi trường đầy đủ
check_environment() {
    check_root
    check_bash
    detect_os
    detect_network_interface
    check_dependencies
}
