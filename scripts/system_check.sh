#!/usr/bin/env bash

# scripts/system_check.sh
#
# Script kiểm tra hệ thống và các thành phần của Dante SOCKS5 proxy server
# Tác giả: ThienTranJP

# Nạp các module cần thiết
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/check_environment.sh"

# Kiểm tra quyền root
check_root

# Hiển thị banner
echo -e "${BLUE}=======================================================${NC}"
echo -e "${GREEN}          Kiểm tra hệ thống Dante SOCKS5 Proxy         ${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo ""

# Kiểm tra các thành phần hệ thống
check_system_components() {
    # Kiểm tra hệ điều hành
    detect_os
    info_message "Hệ điều hành: $OStype"
    
    # Kiểm tra giao diện mạng
    detect_network_interface
    info_message "Giao diện mạng: $interface"
    
    # Kiểm tra IP
    local ip=$(get_ip)
    info_message "Địa chỉ IP: $ip"
    
    # Kiểm tra Dante đã cài đặt chưa
    if is_dante_installed; then
        success_message "Dante SOCKS5 proxy server đã được cài đặt"
        
        # Kiểm tra file cấu hình
        if [[ -f /etc/sockd.conf ]]; then
            success_message "File cấu hình sockd.conf tồn tại"
        else
            error_message "File cấu hình sockd.conf không tồn tại"
        fi
        
        # Kiểm tra dịch vụ
        if systemctl is-active --quiet sockd; then
            success_message "Dịch vụ sockd đang chạy"
        else
            warning_message "Dịch vụ sockd không chạy"
        fi
        
        # Kiểm tra số lượng proxy user
        local user_count=$(get_proxy_users | wc -l)
        info_message "Số lượng proxy user: $user_count"
    else
        warning_message "Dante SOCKS5 proxy server chưa được cài đặt"
    fi
    
    # Kiểm tra các gói phụ thuộc
    echo ""
    info_message "Kiểm tra các gói phụ thuộc:"
    check_dependencies
}

# Chạy kiểm tra
check_system_components
pause
