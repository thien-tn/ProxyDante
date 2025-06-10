#!/usr/bin/env bash

# lib/install_dante.sh
#
# Chứa các hàm cài đặt Dante SOCKS5 proxy server
# Tác giả: akmaslov-dev
# Chỉnh sửa bởi: ThienTranJP

# Cài đặt các gói phụ thuộc
install_dependencies() {
    info_message "Đang cài đặt các gói phụ thuộc..."
    
    if [[ "$OStype" == "debian" || "$OStype" == "ubuntu" ]]; then
        apt-get update
        apt-get install -y make gcc g++ wget curl zip unzip openssl libssl-dev pax-utils
    elif [[ "$OStype" == "centos" ]]; then
        yum -y update
        yum -y install make gcc wget curl zip unzip openssl openssl-devel pax-utils
    fi
    
    success_message "Đã cài đặt các gói phụ thuộc"
}

# Tải và biên dịch Dante
compile_dante() {
    info_message "Đang chuẩn bị biên dịch Dante 1.4.4..."
    
    # Tạo thư mục tạm
    mkdir -p /tmp/danted
    cd /tmp/danted
    
    # Kiểm tra file Dante đã upload
    DANTE_LOCAL_PATH="$(dirname "$0")/../dante-1.4.4.tar.gz"
    
    if [[ -f "$DANTE_LOCAL_PATH" ]]; then
        info_message "Sử dụng file Dante 1.4.4 đã được upload..."
        cp "$DANTE_LOCAL_PATH" ./dante-1.4.4.tar.gz
    else
        info_message "Không tìm thấy file Dante 1.4.4 đã upload, đang tải xuống..."
        # Tải Dante 1.4.4
        wget --no-check-certificate https://www.inet.no/dante/files/dante-1.4.4.tar.gz
        
        # Kiểm tra file tải xuống
        if [[ ! -f dante-1.4.4.tar.gz ]]; then
            error_message "Không thể tải Dante 1.4.4"
            info_message "Thử tải từ nguồn thay thế..."
            wget --no-check-certificate https://github.com/notpeter/dante/archive/dante-1.4.4.tar.gz
            
            if [[ ! -f dante-1.4.4.tar.gz ]]; then
                error_message "Không thể tải Dante 1.4.4 từ cả hai nguồn"
                
                # Thử sử dụng phiên bản cũ hơn
                info_message "Thử sử dụng phiên bản Dante 1.4.3..."
                wget --no-check-certificate https://www.inet.no/dante/files/dante-1.4.3.tar.gz
                
                if [[ ! -f dante-1.4.3.tar.gz ]]; then
                    error_message "Không thể tải Dante từ bất kỳ nguồn nào"
                    exit 1
                fi
            fi
        fi
    fi
    
    # Xác định phiên bản Dante được sử dụng
    if [[ -f dante-1.4.4.tar.gz ]]; then
        DANTE_VERSION="1.4.4"
    else
        DANTE_VERSION="1.4.3"
    fi
    
    info_message "Sử dụng Dante phiên bản $DANTE_VERSION"
    
    # Giải nén
    tar -xzf dante-${DANTE_VERSION}.tar.gz
    
    # Kiểm tra thư mục sau khi giải nén
    if [[ -d dante-${DANTE_VERSION} ]]; then
        cd dante-${DANTE_VERSION}
    elif [[ -d dante-dante-${DANTE_VERSION} ]]; then
        cd dante-dante-${DANTE_VERSION}
    else
        error_message "Không tìm thấy thư mục sau khi giải nén"
        ls -la
        exit 1
    fi
    
    # Cấu hình và biên dịch
    info_message "Cấu hình và biên dịch Dante ${DANTE_VERSION}..."
    ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-client --without-libwrap --without-bsdauth --without-gssapi --without-krb5 --without-upnp --without-pam || {
        error_message "Cấu hình Dante thất bại"
        exit 1
    }
    
    make || {
        error_message "Biên dịch Dante thất bại"
        exit 1
    }
    
    make install || {
        error_message "Cài đặt Dante thất bại"
        exit 1
    }
    
    # Kiểm tra cài đặt
    if command -v sockd >/dev/null 2>&1; then
        success_message "Đã cài đặt Dante ${DANTE_VERSION} thành công"
        
        # Kiểm tra phiên bản
        INSTALLED_VERSION=$(sockd -v 2>&1 | grep -oP 'version \K[0-9\.]+' || echo "unknown")
        info_message "Phiên bản Dante đã cài đặt: $INSTALLED_VERSION"
        
        # Đảm bảo file thực thi có quyền thích hợp
        SOCKD_PATH=$(which sockd)
        info_message "Dante được cài đặt tại: $SOCKD_PATH"
        chmod +x "$SOCKD_PATH"
        
        # Kiểm tra các thư viện động
        info_message "Kiểm tra các thư viện động..."
        if command -v ldd >/dev/null 2>&1; then
            ldd "$SOCKD_PATH"
        fi
        
        # Tạo symlink nếu cần
        if [[ "$SOCKD_PATH" != "/usr/sbin/sockd" ]]; then
            info_message "Tạo symlink từ $SOCKD_PATH đến /usr/sbin/sockd"
            ln -sf "$SOCKD_PATH" /usr/sbin/sockd
            chmod +x /usr/sbin/sockd
        fi
    else
        error_message "Không thể cài đặt Dante"
        exit 1
    fi
    
    # Dọn dẹp
    cd /tmp
    rm -rf /tmp/danted
}

# Tạo file cấu hình sockd.conf
create_config() {
    info_message "Đang tạo file cấu hình /etc/sockd.conf..."
    
    # Kiểm tra nếu có template
    if [[ -f "$(dirname "$0")/../config/sockd.conf.template" ]]; then
        info_message "Sử dụng file template cấu hình..."
        cp "$(dirname "$0")/../config/sockd.conf.template" /etc/sockd.conf
        
        # Thay thế các biến trong template
        sed -i "s/%INTERFACE%/${interface}/g" /etc/sockd.conf
        sed -i "s/%PORT%/${port}/g" /etc/sockd.conf
    else
        # Tạo file cấu hình trực tiếp
        cat > /etc/sockd.conf << EOL
internal: ${interface} port = ${port}
external: ${interface}
user.privileged: root
user.unprivileged: nobody
socksmethod: username
logoutput: /var/log/sockd.log

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
    socksmethod: username
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: error
    socksmethod: username
}
EOL
    fi
    
    # Kiểm tra file cấu hình
    if [[ -f /etc/sockd.conf ]]; then
        success_message "Đã tạo file cấu hình /etc/sockd.conf"
        
        # Kiểm tra cú pháp của file cấu hình
        if command -v sockd >/dev/null 2>&1; then
            info_message "Kiểm tra cú pháp file cấu hình..."
            sockd -V -f /etc/sockd.conf || {
                warning_message "File cấu hình có thể có lỗi cú pháp, nhưng vẫn tiếp tục..."
            }
        fi
    else
        error_message "Không thể tạo file cấu hình /etc/sockd.conf"
        exit 1
    fi
}

# Tạo ngẫu nhiên nhiều proxy user
create_random_proxy() {
    local num=$1
    
    if [[ -z "$num" ]]; then
        num=$numofproxy
    fi
    
    info_message "Đang tạo $num proxy user ngẫu nhiên..."
    
    # Nạp module quản lý user nếu chưa được nạp
    if ! type -t add_to_proxy_file &>/dev/null; then
        source "$(dirname "$0")/user_management.sh"
    fi
    
    # Lấy cổng từ file cấu hình
    local port=$(get_dante_port)
    
    # Lấy địa chỉ IP máy chủ
    local hostname=$(get_server_ip)
    
    # Đảm bảo thư mục và file proxy tồn tại
    ensure_proxy_dir
    
    for ((i=1; i<=num; i++)); do
        # Tạo username và password ngẫu nhiên
        local username="user_$(generate_random_string 8)"
        local password="pass_$(generate_random_string 12)"
        
        # Kiểm tra user đã tồn tại chưa
        if user_exists "$username"; then
            warning_message "User $username đã tồn tại, đang tạo user khác..."
            ((i--))
            continue
        fi
        
        # Tạo user
        useradd -M -s /usr/sbin/nologin "$username"
        echo "$username:$password" | chpasswd
        
        # Lưu proxy vào file quản lý proxy chung
        add_to_proxy_file "$hostname" "$port" "$username" "$password"
        
        success_message "Đã tạo proxy user: $hostname:$port:$username:$password"
    done
    
    # Hiển thị thông báo tổng kết
    success_message "Đã tạo thành công $num proxy user và lưu vào file quản lý proxy"
    info_message "Bạn có thể xem danh sách đầy đủ các proxy bằng lệnh 'list_proxy_users'"
}

# Cài đặt Dante proxy server
install_dante_proxy() {
    # Kiểm tra nếu Dante đã được cài đặt
    if is_dante_installed; then
        info_message "Dante đã được cài đặt trước đó."
        read -p "Bạn có muốn cài đặt lại không? (y/n): " -e -i n REINSTALL
        
        if [[ "$REINSTALL" != 'y' && "$REINSTALL" != 'Y' ]]; then
            info_message "Đã hủy cài đặt lại."
            return 0
        fi
        
        # Dừng và gỡ bỏ dịch vụ hiện tại
        info_message "Dừng và gỡ bỏ dịch vụ hiện tại..."
        systemctl stop sockd 2>/dev/null
        systemctl disable sockd 2>/dev/null
    fi
    
    # Kiểm tra các gói phụ thuộc
    install_dependencies
    
    # Lấy cấu hình từ người dùng
    get_config
    
    # Tải và biên dịch Dante
    compile_dante
    
    # Tạo file cấu hình
    create_config
    
    # Tạo dịch vụ systemd
    create_service
    
    # Tạo proxy user ngẫu nhiên
    create_random_proxy "$numofproxy"
    
    success_message "Cài đặt Dante SOCKS5 proxy server hoàn tất"
    success_message "Bạn có thể quản lý proxy bằng cách chạy lại script này"
    
    # Hiển thị thông tin proxy
    list_proxy_users
}

# Lấy thông tin cấu hình từ người dùng
get_config() {
    # Lấy thông tin cổng
    read -p "Nhập cổng cho Dante SOCKS5 proxy [1080]: " -e -i 1080 port
    
    # Kiểm tra cổng hợp lệ
    if ! is_valid_port "$port"; then
        error_message "Cổng không hợp lệ. Sử dụng cổng mặc định 1080."
        port=1080
    fi
    
    # Kiểm tra cổng đã được sử dụng chưa
    if is_port_in_use "$port"; then
        error_message "Cổng $port đã được sử dụng. Vui lòng chọn cổng khác."
        read -p "Nhập cổng khác cho Dante SOCKS5 proxy [1080]: " -e -i 1080 port
        
        # Kiểm tra lại cổng mới
        if ! is_valid_port "$port" || is_port_in_use "$port"; then
            error_message "Cổng không hợp lệ hoặc đã được sử dụng. Thoát."
            exit 1
        fi
    fi
    
    # Lấy số lượng proxy cần tạo
    read -p "Nhập số lượng proxy ngẫu nhiên cần tạo [5]: " -e -i 5 numofproxy
    
    # Kiểm tra số lượng hợp lệ
    if ! is_valid_number "$numofproxy" || [[ $numofproxy -lt 1 ]]; then
        error_message "Số lượng không hợp lệ. Sử dụng giá trị mặc định 5."
        numofproxy=5
    fi
    
    export port
    export numofproxy
}
