#!/usr/bin/env bash

# lib/user_management.sh
#
# Chứa các hàm quản lý người dùng proxy
# Tác giả: akmaslov-dev
# Chỉnh sửa bởi: ThienTranJP

# Đường dẫn đến file proxy chung
PROXY_FILE="/etc/dante/proxy_list.txt"

# Tạo thư mục chứa file proxy nếu chưa tồn tại
ensure_proxy_dir() {
    if [[ ! -d "/etc/dante" ]]; then
        mkdir -p /etc/dante
    fi
    
    # Tạo file proxy nếu chưa tồn tại
    if [[ ! -f "$PROXY_FILE" ]]; then
        touch "$PROXY_FILE"
        chmod 600 "$PROXY_FILE"
    fi
}

# Thêm proxy vào file proxy chung
add_to_proxy_file() {
    local ip=$1
    local port=$2
    local username=$3
    local password=$4
    
    # Đảm bảo thư mục và file tồn tại
    ensure_proxy_dir
    
    # Kiểm tra xem proxy đã tồn tại chưa
    if grep -q "^$ip:$port:$username:" "$PROXY_FILE" 2>/dev/null; then
        # Cập nhật mật khẩu nếu proxy đã tồn tại
        sed -i "s|^$ip:$port:$username:.*|$ip:$port:$username:$password|" "$PROXY_FILE"
    else
        # Thêm proxy mới vào file
        echo "$ip:$port:$username:$password" >> "$PROXY_FILE"
    fi
    
    info_message "Đã thêm/cập nhật proxy $ip:$port:$username:$password vào file quản lý"
}

# Xóa proxy khỏi file proxy chung
remove_from_proxy_file() {
    local username=$1
    
    # Đảm bảo thư mục và file tồn tại
    ensure_proxy_dir
    
    # Kiểm tra xem proxy có tồn tại không
    if grep -q ":$username:" "$PROXY_FILE" 2>/dev/null; then
        # Xóa proxy khỏi file
        sed -i "/:$username:/d" "$PROXY_FILE"
        info_message "Đã xóa proxy với username $username khỏi file quản lý"
    else
        warning_message "Không tìm thấy proxy với username $username trong file quản lý"
    fi
}

# Hiển thị danh sách proxy user
list_proxy_users() {
    # Đảm bảo thư mục và file tồn tại
    ensure_proxy_dir
    
    # Kiểm tra file proxy có dữ liệu không
    if [[ ! -s "$PROXY_FILE" ]]; then
        # Nếu file proxy rỗng, kiểm tra xem có proxy user nào không
        local users=$(get_proxy_users)
        
        if [[ -z "$users" ]]; then
            warning_message "Không có proxy user nào và file quản lý proxy rỗng"
            pause
            return 1
        else
            # Tạo lại file proxy từ danh sách user
            info_message "File quản lý proxy rỗng, đang tạo lại từ danh sách user..."
            
            # Lấy cổng từ file cấu hình
            local port=$(get_dante_port)
            
            # Lấy địa chỉ IP máy chủ
            local hostname=$(get_server_ip)
            
            # Lặp qua từng user và thêm vào file proxy
            echo "$users" | while read -r user; do
                # Không thể lấy mật khẩu thực từ hệ thống, sử dụng placeholder
                echo "$hostname:$port:$user:password_placeholder" >> "$PROXY_FILE"
            done
            
            warning_message "Mật khẩu trong file proxy là placeholder, cần cập nhật thủ công"
        fi
    fi
    
    # Hiển thị danh sách proxy từ file quản lý
    info_message "Danh sách proxy (IP:Port:Username:Password):"
    echo "----------------------------------------"
    
    # Hiển thị danh sách proxy dạng list đơn giản để dễ copy
    cat "$PROXY_FILE"
    
    echo "----------------------------------------"
    
    # Hiển thị tổng số proxy
    local proxy_count=$(wc -l < "$PROXY_FILE")
    success_message "Tổng số proxy: $proxy_count"
    
    pause
}

# Hàm tạo proxy user và thêm vào file quản lý
create_proxy_user() {
    local username=$1
    local password=$2
    
    # Kiểm tra đầu vào
    if [[ -z "$username" ]]; then
        error_message "Tên đăng nhập không được để trống"
        return 1
    fi
    
    # Kiểm tra user đã tồn tại chưa
    if user_exists "$username"; then
        error_message "User $username đã tồn tại"
        return 2
    fi
    
    # Tạo user
    useradd -M -s /usr/sbin/nologin "$username"
    echo "$username:$password" | chpasswd
    
    # Lấy cổng từ file cấu hình
    local port=$(get_dante_port)
    
    # Lấy địa chỉ IP máy chủ
    local hostname=$(get_server_ip)
    
    # Thêm proxy vào file quản lý
    add_to_proxy_file "$hostname" "$port" "$username" "$password"
    
    # Hiển thị thông tin proxy
    success_message "Đã tạo proxy user:"
    echo "IP: $hostname"
    echo "Port: $port"
    echo "Username: $username"
    echo "Password: $password"
    echo ""
    echo "Proxy string: $hostname:$port:$username:$password"
    
    return 0
}

# Thêm một proxy user mới
add_proxy_user() {
    info_message "Thêm proxy user mới"
    
    # Lấy tên đăng nhập mới
    read -p "Nhập tên cho proxy user mới: " -e -i proxyuser usernew
    echo ""
    
    # Kiểm tra đầu vào
    if [[ -z "$usernew" ]]; then
        error_message "Tên đăng nhập không được để trống"
        pause
        return 1
    fi
    
    # Lấy mật khẩu hoặc tạo mật khẩu ngẫu nhiên
    read -p "Nhập mật khẩu (bỏ trống để tạo mật khẩu ngẫu nhiên): " -e passnew
    echo ""
    
    # Nếu mật khẩu trống, tạo mật khẩu ngẫu nhiên
    if [[ -z "$passnew" ]]; then
        passnew=$(generate_random_string 12)
        info_message "Mật khẩu được tạo ngẫu nhiên: $passnew"
    fi
    
    # Tạo proxy user
    create_proxy_user "$usernew" "$passnew"
    
    pause
}

# Thêm ngẫu nhiên nhiều proxy
add_random_proxies() {
    info_message "Thêm ngẫu nhiên nhiều proxy"
    
    # Lấy số lượng proxy cần tạo
    read -p "Nhập số lượng proxy cần tạo: " -e -i 5 num_proxies
    
    # Kiểm tra đầu vào
    if ! is_valid_number "$num_proxies" || [ "$num_proxies" -lt 1 ]; then
        error_message "Số lượng proxy không hợp lệ"
        pause
        return 1
    fi
    
    info_message "Đang tạo $num_proxies proxy ngẫu nhiên..."
    echo ""
    
    # Đảm bảo thư mục và file proxy tồn tại
    ensure_proxy_dir
    
    # Biến đếm số proxy đã tạo thành công
    local created_count=0
    
    # Tạo các proxy ngẫu nhiên
    while [ $created_count -lt $num_proxies ]; do
        # Tạo username và password ngẫu nhiên
        local username="user_$(generate_random_string 8)"
        local password="pass_$(generate_random_string 12)"
        
        # Kiểm tra user đã tồn tại chưa
        if user_exists "$username"; then
            warning_message "User $username đã tồn tại, đang tạo user khác..."
            continue
        fi
        
        # Tạo proxy user
        echo -e "\n[$((created_count+1))/$num_proxies] Đang tạo proxy user: $username"
        if create_proxy_user "$username" "$password"; then
            ((created_count++))
        fi
    done
    
    echo ""
    success_message "Đã tạo thành công $num_proxies proxy user"
    
    # Hỏi người dùng có muốn xem danh sách proxy không
    read -p "Bạn có muốn xem danh sách proxy đã tạo không? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        list_proxy_users
    else
        pause
    fi
}

# Xóa một proxy user
delete_proxy_user() {
    info_message "Xóa proxy user"
    
    # Lấy danh sách user
    local users=$(get_proxy_users)
    
    if [[ -z "$users" ]]; then
        warning_message "Không có proxy user nào"
        pause
        return 1
    fi
    
    # Hiển thị danh sách user
    echo "Danh sách proxy user:"
    echo "$users"
    echo ""
    
    # Lấy tên user cần xóa
    read -p "Nhập tên proxy user cần xóa: " -e userdel
    
    # Kiểm tra đầu vào
    if [[ -z "$userdel" ]]; then
        error_message "Tên đăng nhập không được để trống"
        pause
        return 2
    fi
    
    # Kiểm tra user có tồn tại không
    if ! user_exists "$userdel"; then
        error_message "User $userdel không tồn tại"
        pause
        return 3
    fi
    
    # Xác nhận xóa
    read -p "Bạn có chắc chắn muốn xóa proxy user $userdel? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info_message "Đã hủy xóa proxy user"
        pause
        return 4
    fi
    
    # Xóa user
    userdel -r "$userdel"
    
    # Xóa proxy khỏi file quản lý
    remove_from_proxy_file "$userdel"
    
    success_message "Đã xóa proxy user: $userdel"
    
    pause
}

# Xóa toàn bộ proxy user
delete_all_proxy_users() {
    info_message "Xóa toàn bộ proxy user"
    
    echo "Danh sách proxy user sẽ bị xóa:"
    local users=$(get_proxy_users)
    
    if [[ -z "$users" ]]; then
        warning_message "Không có proxy user nào"
        pause
        return 1
    fi
    
    echo "$users"
    echo ""
    
    # Xác nhận xóa
    read -p "Bạn có chắc chắn muốn xóa TẤT CẢ proxy user? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info_message "Đã hủy xóa toàn bộ proxy user"
        pause
        return 2
    fi
    
    # Xóa tất cả proxy user
    echo "$users" | while read -r user; do
        userdel -r "$user"
        success_message "Đã xóa user: $user"
        
        # Xóa proxy khỏi file quản lý
        remove_from_proxy_file "$user"
    done
    
    # Tự động xóa nội dung file proxy_list.txt mà không cần xác nhận
    > "$PROXY_FILE"
    success_message "Đã tự động xóa nội dung file quản lý proxy"
    
    success_message "Đã xóa toàn bộ proxy user"
    pause
}

# Xuất danh sách proxy
export_proxy_list() {
    info_message "Xuất danh sách proxy"
    
    # Kiểm tra file quản lý proxy
    ensure_proxy_dir
    
    if [[ ! -s "$PROXY_FILE" ]]; then
        # Nếu file proxy rỗng, tạo lại từ danh sách user
        info_message "File quản lý proxy rỗng, tạo lại từ danh sách user..."
        
        # Lấy danh sách proxy user
        local users=$(get_proxy_users)
        
        if [[ -z "$users" ]]; then
            warning_message "Không có proxy user nào"
            pause
            return 1
        fi
        
        # Lấy cổng từ file cấu hình
        local port=$(get_dante_port)
        
        # Lấy địa chỉ IP máy chủ
        local hostname=$(get_server_ip)
        
        # Làm trống file proxy
        > "$PROXY_FILE"
        
        # Lặp qua từng user và thêm vào file proxy
        echo "$users" | while read -r user; do
            # Không thể lấy mật khẩu thực từ hệ thống, sử dụng placeholder
            echo "$hostname:$port:$user:password_placeholder" >> "$PROXY_FILE"
        done
        
        warning_message "Mật khẩu trong file proxy là placeholder, cần cập nhật thủ công"
    fi
    
    # Tạo hoặc làm trống tệp proxy.txt trong thư mục hiện tại
    local export_file="./proxy_list.txt"
    > "$export_file"
    
    # Xuất danh sách proxy từ file quản lý
    info_message "Danh sách proxy (IP:PORT:LOGIN:PASS):"
    
    # Sao chép nội dung từ file quản lý sang file xuất
    cat "$PROXY_FILE" | tee "$export_file"
    
    success_message "Đã xuất danh sách proxy vào file $export_file"
    info_message "Bạn có thể sao chép danh sách proxy từ file này"
    
    pause
}

