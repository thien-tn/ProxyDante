#!/usr/bin/env bash

# lib/limit_manager.sh
#
# Quản lý giới hạn tốc độ và dữ liệu cho proxy
# Tác giả: ThienTranJP

# Load các thư viện cần thiết
source "${INSTALL_DIR}/lib/limit_speed.sh"
source "${INSTALL_DIR}/lib/data_limit.sh"

# Hiển thị menu quản lý giới hạn
show_limit_manager_menu() {
    while true; do
        clear
        echo "===== QUẢN LÝ GIỚI HẠN PROXY ====="
        echo "1. Quản lý giới hạn tốc độ"
        echo "2. Quản lý giới hạn dữ liệu"
        echo "3. Thiết lập giới hạn cho tất cả user"
        echo "4. Quay lại"
        echo "=================================="
        read -p "Nhập lựa chọn của bạn: " choice
        
        case $choice in
            1) manage_speed_limits ;;
            2) manage_data_limits ;;
            3) setup_limits_for_all_users ;;
            4) return 0 ;;
            *) error_message "Lựa chọn không hợp lệ"; pause ;;
        esac
    done
}

# Quản lý giới hạn tốc độ
manage_speed_limits() {
    while true; do
        clear
        echo "===== QUẢN LÝ GIỚI HẠN TỐC ĐỘ PROXY ====="
        echo "1. Xem giới hạn tốc độ hiện tại"
        echo "2. Thay đổi giới hạn tốc độ"
        echo "3. Xóa giới hạn tốc độ"
        echo "4. Quay lại"
        echo "========================================="
        read -p "Nhập lựa chọn của bạn: " choice
        
        # Lấy giao diện mạng
        local interface=$(ip -o -4 route show to default | awk '{print $5}')
        
        case $choice in
            1) 
                show_speed_limits "$interface"
                pause
                ;;
            2) change_speed_limit ;;
            3) 
                # Hiển thị danh sách proxy user
                echo "Danh sách proxy user:"
                local users=$(get_proxy_users)
                
                if [[ -z "$users" ]]; then
                    warning_message "Không có proxy user nào"
                    pause
                    continue
                fi
                
                echo "$users"
                echo ""
                
                # Hiển thị giới hạn tốc độ hiện tại
                show_speed_limits "$interface"
                
                # Lấy tên user cần xóa giới hạn tốc độ
                read -p "Nhập tên user cần xóa giới hạn tốc độ: " username
                
                # Kiểm tra user tồn tại
                if ! user_exists "$username"; then
                    error_message "User '$username' không tồn tại"
                    pause
                    continue
                fi
                
                # Xóa giới hạn tốc độ
                remove_user_speed_limit "$username" "$interface"
                
                pause
                ;;
            4) return 0 ;;
            *) error_message "Lựa chọn không hợp lệ"; pause ;;
        esac
    done
}

# Quản lý giới hạn dữ liệu
manage_data_limits() {
    # Kiểm tra các công cụ cần thiết
    check_data_limit_dependencies
    
    # Khởi tạo cơ sở dữ liệu
    initialize_data_usage_db
    
    while true; do
        clear
        echo "===== QUẢN LÝ GIỚI HẠN DỮ LIỆU PROXY ====="
        echo "1. Xem lượng dữ liệu đã sử dụng"
        echo "2. Thay đổi giới hạn dữ liệu"
        echo "3. Xóa giới hạn dữ liệu"
        echo "4. Cập nhật lượng dữ liệu sử dụng"
        echo "5. Quay lại"
        echo "=========================================="
        read -p "Nhập lựa chọn của bạn: " choice
        
        case $choice in
            1) 
                show_data_usage
                pause
                ;;
            2) change_data_limit ;;
            3) 
                # Hiển thị danh sách proxy user
                echo "Danh sách proxy user:"
                local users=$(get_proxy_users)
                
                if [[ -z "$users" ]]; then
                    warning_message "Không có proxy user nào"
                    pause
                    continue
                fi
                
                echo "$users"
                echo ""
                
                # Hiển thị lượng dữ liệu đã sử dụng
                show_data_usage
                
                # Lấy tên user cần xóa giới hạn dữ liệu
                read -p "Nhập tên user cần xóa giới hạn dữ liệu: " username
                
                # Kiểm tra user tồn tại
                if ! user_exists "$username"; then
                    error_message "User '$username' không tồn tại"
                    pause
                    continue
                fi
                
                # Xóa giới hạn dữ liệu
                jq --arg username "$username" 'del(.users[$username])' "$DATA_LIMIT_DB" > "${DATA_LIMIT_DB}.tmp" && mv "${DATA_LIMIT_DB}.tmp" "$DATA_LIMIT_DB"
                
                success_message "Đã xóa giới hạn dữ liệu cho user $username"
                pause
                ;;
            4) 
                local users=$(get_proxy_users)
                if [[ -z "$users" ]]; then
                    warning_message "Không có proxy user nào"
                    pause
                    continue
                fi
                echo "$users" | while read -r username; do
                    update_user_data_usage "$username"
                done
                check_and_apply_data_limits
                success_message "Đã cập nhật lượng dữ liệu sử dụng"
                pause
                ;;
            5) return 0 ;;
            *) error_message "Lựa chọn không hợp lệ"; pause ;;
        esac
    done
}

# Thiết lập giới hạn cho tất cả user
setup_limits_for_all_users() {
    clear
    echo "===== THIẾT LẬP GIỚI HẠN CHO TẤT CẢ USER ====="
    
    # Lấy danh sách tất cả proxy users
    local users=$(get_proxy_users)
    
    if [[ -z "$users" ]]; then
        warning_message "Không có proxy user nào"
        pause
        return 1
    fi
    
    # Lấy giới hạn tốc độ
    read -p "Nhập giới hạn tốc độ (Mbps) cho tất cả user (để trống nếu không muốn thiết lập): " speed_limit
    
    # Lấy giới hạn dữ liệu
    read -p "Nhập giới hạn dữ liệu cho tất cả user (để trống nếu không muốn thiết lập): " data_limit
    
    # Lấy đơn vị cho giới hạn dữ liệu
    local data_unit="GB"
    if [[ -n "$data_limit" ]]; then
        read -p "Nhập đơn vị giới hạn dữ liệu (MB/GB, mặc định GB): " data_unit
        
        # Nếu không nhập đơn vị, mặc định là GB
        if [[ -z "$data_unit" ]]; then
            data_unit="GB"
        fi
        
        # Chuyển đơn vị về chữ hoa
        data_unit=$(echo "$data_unit" | tr '[:lower:]' '[:upper:]')
        
        # Kiểm tra đơn vị hợp lệ
        if [[ "$data_unit" != "MB" ]] && [[ "$data_unit" != "GB" ]]; then
            error_message "Đơn vị không hợp lệ. Chỉ chấp nhận MB hoặc GB"
            data_unit="GB"
            warning_message "Sử dụng đơn vị mặc định: GB"
        fi
    fi
    
    # Lấy giao diện mạng
    local interface=$(ip -o -4 route show to default | awk '{print $5}')
    
    # Thiết lập giới hạn cho từng user
    echo "$users" | while read -r username; do
        # Thiết lập giới hạn tốc độ nếu có
        if [[ -n "$speed_limit" ]] && is_valid_number "$speed_limit" 1; then
            # Xóa giới hạn tốc độ cũ nếu có
            remove_user_speed_limit "$username" "$interface"
            
            # Thiết lập giới hạn tốc độ mới
            set_user_speed_limit "$username" "$speed_limit" "$interface"
        fi
        
        # Thiết lập giới hạn dữ liệu nếu có
        if [[ -n "$data_limit" ]] && is_valid_number "$data_limit" 0.1; then
            set_user_data_limit "$username" "$data_limit" "$data_unit"
        fi
    done
    
    success_message "Đã thiết lập giới hạn cho tất cả user"
    
    # Cài đặt cron job để kiểm tra và cập nhật lưu lượng sử dụng hàng ngày
    if [[ -n "$data_limit" ]]; then
        setup_data_limit_cron
    fi
    
    pause
}

# Khởi tạo hệ thống giới hạn
initialize_limit_system() {
    # Kiểm tra tc đã được cài đặt
    check_tc_installed
    
    # Kiểm tra các công cụ cần thiết cho giới hạn dữ liệu
    check_data_limit_dependencies
    
    # Khởi tạo cơ sở dữ liệu
    initialize_data_usage_db
    
    # Lấy giao diện mạng
    local interface=$(ip -o -4 route show to default | awk '{print $5}')
    
    # Khởi tạo tc qdisc
    initialize_tc "$interface"
    
    # Cài đặt cron job
    setup_data_limit_cron
    
    success_message "Đã khởi tạo hệ thống giới hạn"
}
