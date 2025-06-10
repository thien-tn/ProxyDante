#!/usr/bin/env bash

# lib/uninstall.sh
#
# Chứa các hàm gỡ cài đặt Dante SOCKS5 proxy server
# Tác giả: akmaslov-dev
# Chỉnh sửa bởi: ThienTranJP

# Gỡ cài đặt Dante
uninstall_dante() {
    info_message "Gỡ cài đặt Dante SOCKS5 proxy server"
    
    # Xác nhận gỡ cài đặt
    read -p "Bạn có chắc chắn muốn gỡ cài đặt Dante SOCKS5 proxy server? (y/n): " -e -i n REMOVE
    
    if [[ "$REMOVE" != 'y' && "$REMOVE" != 'Y' ]]; then
        info_message "Đã hủy gỡ cài đặt"
        pause
        return 1
    fi
    
    # Dừng và gỡ bỏ dịch vụ
    remove_service
    
    # Xóa file cấu hình
    if [[ -f /etc/sockd.conf ]]; then
        rm -f /etc/sockd.conf
        success_message "Đã xóa file cấu hình /etc/sockd.conf"
    fi
    
    # Xóa binary
    if [[ -f /usr/sbin/sockd ]]; then
        rm -f /usr/sbin/sockd
        success_message "Đã xóa binary /usr/sbin/sockd"
    fi
    
    # Xóa tất cả proxy user
    info_message "Đang xóa tất cả proxy user..."
    
    # Lấy danh sách proxy user
    local users=$(get_proxy_users)
    
    if [[ -n "$users" ]]; then
        echo "$users" | while read -r user; do
            userdel -r "$user"
            success_message "Đã xóa user: $user"
        done
    else
        warning_message "Không có proxy user nào"
    fi
    
    # Xóa hoàn toàn file proxy_list.txt mà không cần xác nhận
    if [[ -f "/etc/dante/proxy_list.txt" ]]; then
        rm -f "/etc/dante/proxy_list.txt"
        success_message "Đã xóa hoàn toàn file quản lý proxy /etc/dante/proxy_list.txt"
    fi
    
    # Xóa thư mục dante nếu rỗng
    if [[ -d "/etc/dante" ]] && [[ -z "$(ls -A /etc/dante 2>/dev/null)" ]]; then
        rmdir "/etc/dante"
        success_message "Đã xóa thư mục /etc/dante"
    fi
    
    success_message "Đã gỡ cài đặt Dante SOCKS5 proxy server thành công"
    pause
}
