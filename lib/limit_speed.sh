#!/usr/bin/env bash

# lib/limit_speed.sh
#
# Chứa các hàm giới hạn tốc độ proxy
# Tác giả: akmaslov-dev
# Chỉnh sửa bởi: ThienTranJP

# Đường dẫn đến file cấu hình
TC_CONFIG_FILE="${INSTALL_DIR}/data/tc_config.sh"

# Kiểm tra và cài đặt tc (traffic control)
check_tc_installed() {
    if ! command -v tc &> /dev/null; then
        warning_message "Công cụ tc (traffic control) chưa được cài đặt"
        
        # Cài đặt tc
        if [[ "$OStype" = 'deb' ]]; then
            apt-get -y install iproute2
        else
            yum -y install iproute-tc
        fi
        
        success_message "Đã cài đặt tc (traffic control)"
    fi
    
    # Kiểm tra iptables-persistent đã được cài đặt (cho Debian/Ubuntu)
    if [[ "$OStype" = 'deb' ]] && ! dpkg -l | grep -q iptables-persistent; then
        warning_message "Công cụ iptables-persistent chưa được cài đặt"
        
        # Cài đặt iptables-persistent
        apt-get -y install iptables-persistent
        
        success_message "Đã cài đặt iptables-persistent"
    fi
}

# Khởi tạo tc qdisc
initialize_tc() {
    local interface=$1
    
    # Kiểm tra giao diện mạng tồn tại
    if ! ip link show dev "$interface" &>/dev/null; then
        error_message "Giao diện mạng $interface không tồn tại"
        return 1
    fi
    
    # Xóa qdisc hiện tại nếu có
    tc qdisc del dev "$interface" root 2>/dev/null
    tc qdisc del dev "$interface" ingress 2>/dev/null
    
    # Thiết lập root qdisc cho lưu lượng đi ra (egress)
    tc qdisc add dev "$interface" root handle 1: htb default 1
    
    # Tạo class chính
    tc class add dev "$interface" parent 1: classid 1:1 htb rate 1000mbit
    
    # Thiết lập ingress qdisc cho lưu lượng đi vào
    tc qdisc add dev "$interface" handle ffff: ingress
    
    success_message "Đã khởi tạo tc qdisc trên giao diện $interface"
    
    # Lưu cấu hình
    save_tc_config "$interface"
}

# Thiết lập giới hạn tốc độ cho user
# $1: Tên user
# $2: Giới hạn tốc độ (Mbps)
# $3: Giao diện mạng
set_user_speed_limit() {
    local username=$1
    local limit=$2
    local interface=$3
    
    # Kiểm tra user tồn tại
    if ! user_exists "$username"; then
        error_message "User '$username' không tồn tại"
        return 1
    fi
    
    # Kiểm tra giới hạn tốc độ hợp lệ
    if ! is_valid_number "$limit" 1; then
        error_message "Giới hạn tốc độ không hợp lệ"
        return 2
    fi
    
    # Kiểm tra giao diện mạng tồn tại
    if ! ip link show dev "$interface" &>/dev/null; then
        error_message "Giao diện mạng $interface không tồn tại"
        return 3
    fi
    
    # Lấy UID của user
    local uid=$(id -u "$username")
    
    # Kiểm tra nếu chưa có root qdisc, tạo mới
    if ! tc qdisc show dev "$interface" | grep -q "qdisc htb 1:"; then
        initialize_tc "$interface"
    fi
    
    # Kiểm tra nếu chưa có ingress qdisc, tạo mới
    if ! tc qdisc show dev "$interface" | grep -q "qdisc ingress"; then
        tc qdisc add dev "$interface" handle ffff: ingress 2>/dev/null
    fi
    
    # Tạo class cho user (egress - lưu lượng đi ra)
    local class_id=$((uid + 100))
    tc class add dev "$interface" parent 1: classid 1:$class_id htb rate ${limit}mbit ceil ${limit}mbit
    
    # Tạo filter để phân loại lưu lượng đi ra của user
    tc filter add dev "$interface" protocol ip parent 1: prio 1 handle $uid fw flowid 1:$class_id
    
    # Thiết lập iptables để đánh dấu gói tin đi ra
    iptables -t mangle -D OUTPUT -m owner --uid-owner $uid -j MARK --set-mark $uid 2>/dev/null
    iptables -t mangle -A OUTPUT -m owner --uid-owner $uid -j MARK --set-mark $uid
    
    # Thiết lập giới hạn cho lưu lượng đi vào (ingress - download)
    # Sử dụng police để giới hạn tốc độ đi vào
    tc filter add dev "$interface" parent ffff: protocol ip prio 1 u32 \
        match ip dst 0.0.0.0/0 \
        match ip dport 1024-65535 0xffff \
        match ip protocol 6 0xff \
        match ip tos 0 0xff \
        match ip ttl 0 0xff \
        match ip version 4 0xff \
        match ip src 0.0.0.0/0 \
        flowid :1 \
        action police rate ${limit}mbit burst 10k drop
    
    # Lưu cấu hình
    save_tc_config "$interface"
    
    # Lưu cấu hình iptables
    if [[ "$OStype" = 'deb' ]]; then
        netfilter-persistent save
    else
        service iptables save
    fi
    
    success_message "Đã thiết lập giới hạn tốc độ ${limit}Mbps cho user $username (cả upload và download)"
}

# Xóa giới hạn tốc độ cho user
# $1: Tên user
# $2: Giao diện mạng
remove_user_speed_limit() {
    local username=$1
    local interface=$2
    
    # Kiểm tra user tồn tại
    if ! user_exists "$username"; then
        error_message "User '$username' không tồn tại"
        return 1
    fi
    
    # Kiểm tra giao diện mạng tồn tại
    if ! ip link show dev "$interface" &>/dev/null; then
        error_message "Giao diện mạng $interface không tồn tại"
        return 2
    fi
    
    # Lấy UID của user
    local uid=$(id -u "$username")
    
    # Xóa filter cho lưu lượng đi ra
    tc filter del dev "$interface" protocol ip parent 1: prio 1 handle $uid fw flowid 1:$((uid + 100)) 2>/dev/null
    
    # Xóa class
    tc class del dev "$interface" parent 1: classid 1:$((uid + 100)) 2>/dev/null
    
    # Xóa iptables rule
    iptables -t mangle -D OUTPUT -m owner --uid-owner $uid -j MARK --set-mark $uid 2>/dev/null
    
    # Xóa filter cho lưu lượng đi vào (ingress)
    # Lưu ý: Không thể xóa filter cụ thể cho user trong ingress, nên ta xóa tất cả và tạo lại
    tc filter del dev "$interface" parent ffff: protocol ip prio 1 2>/dev/null
    
    # Lưu cấu hình
    save_tc_config "$interface"
    
    # Lưu cấu hình iptables
    if [[ "$OStype" = 'deb' ]]; then
        netfilter-persistent save
    else
        service iptables save
    fi
    
    success_message "Đã xóa giới hạn tốc độ cho user $username"
}

# Hiển thị giới hạn tốc độ hiện tại
show_speed_limits() {
    local interface=$1
    
    # Kiểm tra giao diện mạng tồn tại
    if ! ip link show dev "$interface" &>/dev/null; then
        error_message "Giao diện mạng $interface không tồn tại"
        return 1
    fi
    
    info_message "Danh sách giới hạn tốc độ hiện tại:"
    
    # Kiểm tra nếu có root qdisc
    if ! tc qdisc show dev "$interface" | grep -q "qdisc htb 1:"; then
        warning_message "Chưa có giới hạn tốc độ nào được thiết lập"
        return 2
    fi
    
    # Hiển thị danh sách class
    echo "Giới hạn tốc độ upload:"
    tc class show dev "$interface" | grep "class htb 1:"
    
    # Hiển thị thông tin về ingress (download)
    echo "\nGiới hạn tốc độ download:"
    tc filter show dev "$interface" parent ffff:
}

# Thay đổi giới hạn tốc độ proxy
change_speed_limit() {
    info_message "Thay đổi giới hạn tốc độ proxy"
    
    # Kiểm tra tc đã được cài đặt
    check_tc_installed
    
    # Lấy giao diện mạng
    local interface=$(ip -o -4 route show to default | awk '{print $5}')
    
    # Kiểm tra giao diện mạng tồn tại
    if [[ -z "$interface" ]]; then
        error_message "Không tìm thấy giao diện mạng mặc định"
        pause
        return 1
    fi
    
    # Hiển thị danh sách proxy user
    echo "Danh sách proxy user:"
    local users=$(get_proxy_users)
    
    if [[ -z "$users" ]]; then
        warning_message "Không có proxy user nào"
        pause
        return 2
    fi
    
    echo "$users"
    echo ""
    
    # Hiển thị giới hạn tốc độ hiện tại
    show_speed_limits "$interface"
    
    # Lấy tên user cần thay đổi giới hạn tốc độ
    read -p "Nhập tên user cần thay đổi giới hạn tốc độ: " username
    
    # Kiểm tra user tồn tại
    if ! user_exists "$username"; then
        error_message "User '$username' không tồn tại"
        pause
        return 3
    fi
    
    # Lấy giới hạn tốc độ mới
    read -p "Nhập giới hạn tốc độ mới (Mbps): " newlimit
    
    # Kiểm tra giới hạn tốc độ hợp lệ
    if ! is_valid_number "$newlimit" 1; then
        error_message "Giới hạn tốc độ không hợp lệ"
        pause
        return 4
    fi
    
    # Xóa giới hạn tốc độ cũ nếu có
    remove_user_speed_limit "$username" "$interface"
    
    # Thiết lập giới hạn tốc độ mới
    set_user_speed_limit "$username" "$newlimit" "$interface"
    
    success_message "Đã thay đổi giới hạn tốc độ thành ${newlimit}Mbps cho user $username (cả upload và download)"
    pause
}

# Lưu cấu hình tc
save_tc_config() {
    local interface=$1
    
    # Tạo thư mục data nếu chưa tồn tại
    mkdir -p "${INSTALL_DIR}/data"
    
    # Tạo file cấu hình
    cat > "$TC_CONFIG_FILE" << EOF
#!/usr/bin/env bash

# Cấu hình tc được tạo tự động
# Ngày tạo: $(date)

# Xóa cấu hình cũ
tc qdisc del dev $interface root 2>/dev/null
tc qdisc del dev $interface ingress 2>/dev/null

# Thiết lập lại cấu hình
$(tc qdisc show dev $interface | grep -v "^qdisc pfifo" | while read line; do echo "tc $line"; done)
$(tc class show dev $interface | while read line; do echo "tc $line"; done)
$(tc filter show dev $interface | while read line; do echo "tc $line"; done)

# Thiết lập lại iptables
$(iptables-save | grep MARK | grep -v "^#" | sed 's/^-A/iptables -t mangle -A/')
EOF
    
    # Cấp quyền thực thi
    chmod +x "$TC_CONFIG_FILE"
    
    success_message "Đã lưu cấu hình tc"
}

# Khôi phục cấu hình tc
restore_tc_config() {
    # Kiểm tra file cấu hình tồn tại
    if [[ -f "$TC_CONFIG_FILE" ]]; then
        # Thực thi file cấu hình
        bash "$TC_CONFIG_FILE"
        
        success_message "Đã khôi phục cấu hình tc"
    else
        warning_message "Không tìm thấy file cấu hình tc"
    fi
}
