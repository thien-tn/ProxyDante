#!/usr/bin/env bash

# lib/data_limit.sh
#
# Chứa các hàm giới hạn lượng dữ liệu sử dụng cho proxy
# Tác giả: ThienTranJP

# Đường dẫn đến file cơ sở dữ liệu
DATA_USAGE_DB="${INSTALL_DIR}/data/data_usage.json"
DATA_LIMIT_DB="${INSTALL_DIR}/data/data_limits.json"

# Kiểm tra và cài đặt các công cụ cần thiết
check_data_limit_dependencies() {
    # Kiểm tra jq đã được cài đặt
    if ! command -v jq &> /dev/null; then
        warning_message "Công cụ jq chưa được cài đặt"
        
        # Cài đặt jq
        if [[ "$OStype" = 'deb' ]]; then
            apt-get -y install jq
        else
            yum -y install jq
        fi
        
        success_message "Đã cài đặt jq"
    fi
    
    # Kiểm tra iptables-persistent đã được cài đặt
    if [[ "$OStype" = 'deb' ]] && ! dpkg -l | grep -q iptables-persistent; then
        warning_message "Công cụ iptables-persistent chưa được cài đặt"
        
        # Cài đặt iptables-persistent
        apt-get -y install iptables-persistent
        
        success_message "Đã cài đặt iptables-persistent"
    fi
}

# Khởi tạo cơ sở dữ liệu
initialize_data_usage_db() {
    # Tạo thư mục data nếu chưa tồn tại
    mkdir -p "${INSTALL_DIR}/data"
    
    # Khởi tạo file data_usage.json nếu chưa tồn tại
    if [[ ! -f "$DATA_USAGE_DB" ]]; then
        echo '{"users": {}}' > "$DATA_USAGE_DB"
        success_message "Đã khởi tạo cơ sở dữ liệu sử dụng dữ liệu"
    fi
    
    # Khởi tạo file data_limits.json nếu chưa tồn tại
    if [[ ! -f "$DATA_LIMIT_DB" ]]; then
        echo '{"users": {}}' > "$DATA_LIMIT_DB"
        success_message "Đã khởi tạo cơ sở dữ liệu giới hạn dữ liệu"
    fi
}

# Cập nhật lượng dữ liệu đã sử dụng cho user
# $1: Tên user
update_user_data_usage() {
    local username=$1
    
    # Kiểm tra user tồn tại
    if ! user_exists "$username"; then
        error_message "User '$username' không tồn tại"
        return 1
    fi
    
    # Lấy UID của user
    local uid=$(id -u "$username")
    
    # Lấy lượng dữ liệu đã sử dụng từ iptables
    local download=$(iptables -L INPUT -v -n -x | grep "owner UID match $uid" | awk '{sum += $2} END {print sum}')
    local upload=$(iptables -L OUTPUT -v -n -x | grep "owner UID match $uid" | awk '{sum += $2} END {print sum}')
    
    # Nếu không có dữ liệu, gán giá trị 0
    download=${download:-0}
    upload=${upload:-0}
    
    # Lấy ngày hiện tại
    local current_date=$(date +"%Y-%m-%d")
    
    # Cập nhật dữ liệu vào cơ sở dữ liệu
    if jq -e ".users[\"$username\"]" "$DATA_USAGE_DB" > /dev/null 2>&1; then
        # User đã tồn tại trong DB, cập nhật dữ liệu
        jq --arg username "$username" \
           --arg date "$current_date" \
           --argjson dl "$download" \
           --argjson ul "$upload" \
           '.users[$username][$date] = {"download": $dl, "upload": $ul}' \
           "$DATA_USAGE_DB" > "${DATA_USAGE_DB}.tmp" && mv "${DATA_USAGE_DB}.tmp" "$DATA_USAGE_DB"
    else
        # User chưa tồn tại trong DB, tạo mới
        jq --arg username "$username" \
           --arg date "$current_date" \
           --argjson dl "$download" \
           --argjson ul "$upload" \
           '.users[$username] = {($date): {"download": $dl, "upload": $ul}}' \
           "$DATA_USAGE_DB" > "${DATA_USAGE_DB}.tmp" && mv "${DATA_USAGE_DB}.tmp" "$DATA_USAGE_DB"
    fi
    
    success_message "Đã cập nhật lượng dữ liệu sử dụng cho user $username"
}

# Thiết lập giới hạn lượng dữ liệu cho user
# $1: Tên user
# $2: Giới hạn dữ liệu (GB)
set_user_data_limit() {
    local username=$1
    local limit=$2
    
    # Kiểm tra user tồn tại
    if ! user_exists "$username"; then
        error_message "User '$username' không tồn tại"
        return 1
    fi
    
    # Kiểm tra giới hạn dữ liệu hợp lệ
    if ! is_valid_number "$limit" 1; then
        error_message "Giới hạn dữ liệu không hợp lệ"
        return 2
    fi
    
    # Cập nhật giới hạn dữ liệu vào cơ sở dữ liệu
    jq --arg username "$username" \
       --argjson limit "$limit" \
       '.users[$username] = {"limit": $limit}' \
       "$DATA_LIMIT_DB" > "${DATA_LIMIT_DB}.tmp" && mv "${DATA_LIMIT_DB}.tmp" "$DATA_LIMIT_DB"
    
    success_message "Đã thiết lập giới hạn dữ liệu ${limit}GB cho user $username"
    
    # Thiết lập iptables để theo dõi lưu lượng
    setup_user_data_tracking "$username"
}

# Thiết lập theo dõi lưu lượng dữ liệu cho user
# $1: Tên user
setup_user_data_tracking() {
    local username=$1
    
    # Kiểm tra user tồn tại
    if ! user_exists "$username"; then
        error_message "User '$username' không tồn tại"
        return 1
    fi
    
    # Lấy UID của user
    local uid=$(id -u "$username")
    
    # Xóa rules cũ nếu có
    iptables -D INPUT -m owner --uid-owner $uid -j ACCEPT 2>/dev/null
    iptables -D OUTPUT -m owner --uid-owner $uid -j ACCEPT 2>/dev/null
    
    # Thêm rules mới để theo dõi lưu lượng
    iptables -A INPUT -m owner --uid-owner $uid -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner $uid -j ACCEPT
    
    # Lưu cấu hình iptables
    if [[ "$OStype" = 'deb' ]]; then
        netfilter-persistent save
    else
        service iptables save
    fi
    
    success_message "Đã thiết lập theo dõi lưu lượng dữ liệu cho user $username"
}

# Tính tổng lượng dữ liệu đã sử dụng trong 30 ngày gần nhất
# $1: Tên user
calculate_user_data_usage() {
    local username=$1
    
    # Kiểm tra user tồn tại
    if ! user_exists "$username"; then
        error_message "User '$username' không tồn tại"
        return 1
    fi
    
    # Kiểm tra user có trong cơ sở dữ liệu không
    if ! jq -e ".users[\"$username\"]" "$DATA_USAGE_DB" > /dev/null 2>&1; then
        echo "0"
        return 0
    fi
    
    # Lấy ngày 30 ngày trước
    local thirty_days_ago=$(date -d "30 days ago" +"%Y-%m-%d")
    
    # Tính tổng lượng dữ liệu đã sử dụng
    local total_usage=$(jq --arg username "$username" \
                          --arg date "$thirty_days_ago" \
                          '
                          .users[$username] | to_entries |
                          map(select(.key >= $date)) |
                          map(.value.download + .value.upload) |
                          add // 0
                          ' "$DATA_USAGE_DB")
    
    # Chuyển đổi từ byte sang GB
    local total_usage_gb=$(echo "scale=2; $total_usage / 1024 / 1024 / 1024" | bc)
    
    echo "$total_usage_gb"
}

# Kiểm tra và áp dụng giới hạn dữ liệu
check_and_apply_data_limits() {
    # Lấy danh sách tất cả proxy users
    local users=$(get_proxy_users)
    
    if [[ -z "$users" ]]; then
        warning_message "Không có proxy user nào"
        return 1
    fi
    
    # Duyệt qua từng user
    echo "$users" | while read -r username; do
        # Kiểm tra user có giới hạn dữ liệu không
        if ! jq -e ".users[\"$username\"]" "$DATA_LIMIT_DB" > /dev/null 2>&1; then
            continue
        fi
        
        # Lấy giới hạn dữ liệu
        local limit=$(jq -r --arg username "$username" '.users[$username].limit' "$DATA_LIMIT_DB")
        
        # Lấy lượng dữ liệu đã sử dụng
        local usage=$(calculate_user_data_usage "$username")
        
        # So sánh với giới hạn
        if (( $(echo "$usage > $limit" | bc -l) )); then
            # Vượt quá giới hạn, tạm khóa tài khoản
            warning_message "User $username đã sử dụng ${usage}GB, vượt quá giới hạn ${limit}GB"
            
            # Lấy UID của user
            local uid=$(id -u "$username")
            
            # Thêm rules để chặn lưu lượng
            iptables -I INPUT -m owner --uid-owner $uid -j DROP
            iptables -I OUTPUT -m owner --uid-owner $uid -j DROP
            
            # Lưu cấu hình iptables
            if [[ "$OStype" = 'deb' ]]; then
                netfilter-persistent save
            else
                service iptables save
            fi
            
            warning_message "Đã tạm khóa tài khoản $username do vượt quá giới hạn dữ liệu"
        fi
    done
}

# Hiển thị lượng dữ liệu đã sử dụng
show_data_usage() {
    info_message "Danh sách lượng dữ liệu đã sử dụng trong 30 ngày gần nhất:"
    
    # Lấy danh sách tất cả proxy users
    local users=$(get_proxy_users)
    
    if [[ -z "$users" ]]; then
        warning_message "Không có proxy user nào"
        return 1
    fi
    
    # Hiển thị header
    printf "%-20s %-15s %-15s\n" "User" "Đã sử dụng (GB)" "Giới hạn (GB)"
    printf "%-20s %-15s %-15s\n" "--------------------" "---------------" "---------------"
    
    # Duyệt qua từng user
    echo "$users" | while read -r username; do
        # Lấy lượng dữ liệu đã sử dụng
        local usage=$(calculate_user_data_usage "$username")
        
        # Lấy giới hạn dữ liệu
        local limit="Không giới hạn"
        if jq -e ".users[\"$username\"]" "$DATA_LIMIT_DB" > /dev/null 2>&1; then
            limit=$(jq -r --arg username "$username" '.users[$username].limit' "$DATA_LIMIT_DB")
            limit="${limit}GB"
        fi
        
        # Hiển thị thông tin
        printf "%-20s %-15s %-15s\n" "$username" "${usage}GB" "$limit"
    done
}

# Thay đổi giới hạn dữ liệu proxy
change_data_limit() {
    info_message "Thay đổi giới hạn dữ liệu proxy"
    
    # Kiểm tra các công cụ cần thiết
    check_data_limit_dependencies
    
    # Khởi tạo cơ sở dữ liệu
    initialize_data_usage_db
    
    # Hiển thị danh sách proxy user
    echo "Danh sách proxy user:"
    local users=$(get_proxy_users)
    
    if [[ -z "$users" ]]; then
        warning_message "Không có proxy user nào"
        pause
        return 1
    fi
    
    echo "$users"
    echo ""
    
    # Hiển thị lượng dữ liệu đã sử dụng
    show_data_usage
    
    # Lấy tên user cần thay đổi giới hạn dữ liệu
    read -p "Nhập tên user cần thay đổi giới hạn dữ liệu: " username
    
    # Kiểm tra user tồn tại
    if ! user_exists "$username"; then
        error_message "User '$username' không tồn tại"
        pause
        return 2
    fi
    
    # Lấy giới hạn dữ liệu mới
    read -p "Nhập giới hạn dữ liệu mới (GB): " newlimit
    
    # Kiểm tra giới hạn dữ liệu hợp lệ
    if ! is_valid_number "$newlimit" 1; then
        error_message "Giới hạn dữ liệu không hợp lệ"
        pause
        return 3
    fi
    
    # Thiết lập giới hạn dữ liệu mới
    set_user_data_limit "$username" "$newlimit"
    
    success_message "Đã thay đổi giới hạn dữ liệu thành ${newlimit}GB cho user $username"
    pause
}

# Cài đặt cron job để kiểm tra và cập nhật lưu lượng sử dụng hàng ngày
setup_data_limit_cron() {
    # Tạo script để chạy hàng ngày
    local cron_script="${INSTALL_DIR}/scripts/update_data_usage.sh"
    
    # Tạo thư mục scripts nếu chưa tồn tại
    mkdir -p "${INSTALL_DIR}/scripts"
    
    # Tạo script
    cat > "$cron_script" << 'EOF'
#!/usr/bin/env bash

# Script cập nhật lượng dữ liệu sử dụng hàng ngày

# Lấy đường dẫn cài đặt
INSTALL_DIR="$(dirname "$(dirname "$0")")"

# Load các thư viện cần thiết
source "${INSTALL_DIR}/lib/common.sh"
source "${INSTALL_DIR}/lib/data_limit.sh"

# Lấy danh sách tất cả proxy users
users=$(get_proxy_users)

if [[ -z "$users" ]]; then
    exit 0
fi

# Cập nhật lượng dữ liệu sử dụng cho từng user
echo "$users" | while read -r username; do
    update_user_data_usage "$username"
done

# Kiểm tra và áp dụng giới hạn dữ liệu
check_and_apply_data_limits
EOF
    
    # Cấp quyền thực thi cho script
    chmod +x "$cron_script"
    
    # Thêm cron job
    (crontab -l 2>/dev/null || echo "") | grep -v "$cron_script" | { cat; echo "0 0 * * * $cron_script"; } | crontab -
    
    success_message "Đã cài đặt cron job để kiểm tra và cập nhật lưu lượng sử dụng hàng ngày"
}

# Bổ sung menu chính
show_data_limit_menu() {
    clear
    echo "===== QUẢN LÝ GIỚI HẠN DỮ LIỆU PROXY ====="
    echo "1. Xem lượng dữ liệu đã sử dụng"
    echo "2. Thay đổi giới hạn dữ liệu"
    echo "3. Cập nhật lượng dữ liệu sử dụng"
    echo "4. Quay lại"
    echo "========================================"
    read -p "Nhập lựa chọn của bạn: " choice
    
    case $choice in
        1) show_data_usage; pause ;;
        2) change_data_limit ;;
        3) 
            local users=$(get_proxy_users)
            if [[ -z "$users" ]]; then
                warning_message "Không có proxy user nào"
                pause
                return 1
            fi
            echo "$users" | while read -r username; do
                update_user_data_usage "$username"
            done
            check_and_apply_data_limits
            success_message "Đã cập nhật lượng dữ liệu sử dụng"
            pause
            ;;
        4) return 0 ;;
        *) error_message "Lựa chọn không hợp lệ"; pause ;;
    esac
}
