#!/usr/bin/env bash

# lib/setup_service.sh
#
# Chứa các hàm thiết lập dịch vụ Dante SOCKS5 proxy
# Tác giả: akmaslov-dev
# Chỉnh sửa bởi: ThienTranJP

# Tạo dịch vụ systemd cho Dante
create_service() {
    info_message "Đang tạo dịch vụ systemd cho Dante..."
    
    # Kiểm tra xem file sockd có tồn tại không
    if [[ ! -f /usr/sbin/sockd ]]; then
        error_message "Không tìm thấy file /usr/sbin/sockd"
        info_message "Đang kiểm tra vị trí khác..."
        
        # Tìm kiếm file sockd
        SOCKD_PATH=$(find / -name sockd -type f 2>/dev/null | grep -v "find:" | head -1)
        
        if [[ -z "$SOCKD_PATH" ]]; then
            error_message "Không tìm thấy file sockd trên hệ thống"
            info_message "Có thể Dante chưa được cài đặt đúng cách"
            
            # Kiểm tra xem có thể cài đặt lại Dante không
            read -p "Bạn có muốn cài đặt lại Dante không? (y/n): " -e -i y REINSTALL_DANTE
            
            if [[ "$REINSTALL_DANTE" == "y" || "$REINSTALL_DANTE" == "Y" ]]; then
                info_message "Cài đặt lại Dante..."
                # Gọi hàm cài đặt Dante từ module install_dante.sh
                compile_dante
            else
                return 1
            fi
        else
            success_message "Đã tìm thấy sockd tại: $SOCKD_PATH"
            info_message "Đang tạo symlink đến /usr/sbin/sockd..."
            ln -sf "$SOCKD_PATH" /usr/sbin/sockd
        fi
    fi
    
    # Kiểm tra quyền thực thi
    if [[ ! -x /usr/sbin/sockd ]]; then
        info_message "Đang cấp quyền thực thi cho /usr/sbin/sockd..."
        chmod +x /usr/sbin/sockd
    fi
    
    # Kiểm tra các thư viện động cần thiết
    info_message "Kiểm tra các thư viện động cần thiết..."
    if command -v ldd >/dev/null 2>&1; then
        MISSING_LIBS=$(ldd /usr/sbin/sockd 2>&1 | grep "not found")
        if [[ -n "$MISSING_LIBS" ]]; then
            warning_message "Thiếu một số thư viện động:"
            echo "$MISSING_LIBS"
            
            # Cài đặt các gói phụ thuộc
            info_message "Cài đặt các gói phụ thuộc..."
            if [[ "$OStype" == "debian" ]]; then
                apt-get update
                apt-get install -y libc6 libpam0g libwrap0
            elif [[ "$OStype" == "centos" ]]; then
                yum install -y glibc pam tcp_wrappers-libs
            fi
        else
            success_message "Tất cả các thư viện động đều đầy đủ"
        fi
    else
        warning_message "Không tìm thấy lệnh ldd để kiểm tra thư viện động"
    fi
    
    # Kiểm tra xem sockd có thể chạy được không
    info_message "Kiểm tra xem sockd có thể chạy được không..."
    if ! /usr/sbin/sockd -V >/dev/null 2>&1; then
        error_message "sockd không thể chạy. Có thể có vấn đề với file thực thi hoặc thư viện động."
        info_message "Thử chạy sockd với quyền root..."
        sudo /usr/sbin/sockd -V
    else
        success_message "sockd có thể chạy được"
    fi
    
    # Tạo file service từ template nếu tồn tại
    if [[ -f "$(dirname "$0")/../config/sockd.service.template" ]]; then
        cp "$(dirname "$0")/../config/sockd.service.template" /etc/systemd/system/sockd.service
    else
        # Tạo file service trực tiếp
        cat > /etc/systemd/system/sockd.service << EOL
[Unit]
Description=Dante Socks Proxy v1.4.4
After=network.target

[Service]
Type=forking
PIDFile=/var/run/sockd.pid
ExecStart=/usr/sbin/sockd -D -f /etc/sockd.conf
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable và start service
    systemctl enable sockd
    if systemctl start sockd; then
        success_message "Đã khởi động dịch vụ Dante"
    else
        error_message "Không thể khởi động dịch vụ Dante"
        systemctl status sockd
        
        # Kiểm tra lỗi chi tiết
        info_message "Đang kiểm tra lỗi chi tiết..."
        journalctl -xeu sockd.service
        
        # Kiểm tra file cấu hình
        info_message "Đang kiểm tra file cấu hình..."
        if [[ -f /etc/sockd.conf ]]; then
            info_message "File cấu hình tồn tại, đang kiểm tra cú pháp..."
            if command -v sockd >/dev/null 2>&1; then
                sockd -V -f /etc/sockd.conf
            fi
        else
            error_message "Không tìm thấy file cấu hình /etc/sockd.conf"
        fi
    fi
}

# Dừng dịch vụ Dante
stop_service() {
    info_message "Đang dừng dịch vụ Dante..."
    
    if systemctl is-active --quiet sockd; then
        systemctl stop sockd
        success_message "Dịch vụ Dante đã được dừng"
    else
        warning_message "Dịch vụ Dante không đang chạy"
    fi
}

# Khởi động lại dịch vụ Dante
restart_service() {
    info_message "Đang khởi động lại dịch vụ Dante..."
    
    systemctl restart sockd
    
    if systemctl is-active --quiet sockd; then
        success_message "Dịch vụ Dante đã được khởi động lại thành công"
    else
        error_message "Không thể khởi động lại dịch vụ Dante"
        systemctl status sockd
        exit 10
    fi
}

# Kiểm tra trạng thái dịch vụ Dante
check_service_status() {
    info_message "Trạng thái dịch vụ Dante:"
    systemctl status sockd
}

# Gỡ bỏ dịch vụ Dante
remove_service() {
    info_message "Đang gỡ bỏ dịch vụ Dante..."
    
    # Dừng dịch vụ
    stop_service
    
    # Vô hiệu hóa dịch vụ
    systemctl disable sockd
    
    # Xóa file service
    rm -f /etc/systemd/system/sockd.service
    
    # Khởi động lại daemon systemd
    systemctl daemon-reload
    
    success_message "Đã gỡ bỏ dịch vụ Dante"
}
