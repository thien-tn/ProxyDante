#!/usr/bin/env bash

# install.sh
#
# Script cài đặt và quản lý Dante SOCKS5 proxy server
# Hỗ trợ Debian, Ubuntu và CentOS
# Tác giả gốc: akmaslov-dev
# Chỉnh sửa bởi: ThienTranJP
#
# Script này cung cấp các chức năng:
# - Cài đặt Dante SOCKS5 proxy server
# - Quản lý proxy user (thêm, xóa, liệt kê)

# - Xuất danh sách proxy
# - Gỡ cài đặt Dante

# Nạp các module cần thiết
source "$(dirname "$0")/lib/common.sh"
source "$(dirname "$0")/lib/check_environment.sh"
source "$(dirname "$0")/lib/install_dante.sh"
source "$(dirname "$0")/lib/setup_service.sh"
source "$(dirname "$0")/lib/user_management.sh"

source "$(dirname "$0")/lib/uninstall.sh"

# Hiển thị banner
show_banner() {
    clear
    echo -e "${BLUE}=======================================================${NC}"
    echo -e "${GREEN}          Dante SOCKS5 Proxy Server Manager           ${NC}"
    echo -e "${GREEN}                  Phiên bản 2.0                       ${NC}"
    echo -e "${BLUE}=======================================================${NC}"
    echo -e "${YELLOW}Tác giả gốc: akmaslov-dev${NC}"
    echo -e "${YELLOW}Chỉnh sửa bởi: ThienTranJP${NC}"
    echo -e "${BLUE}=======================================================${NC}"
    echo ""
}

# Hiển thị menu chính và xử lý lựa chọn
show_main_menu() {
    while true; do
        show_banner
        
        echo "Quản lý Dante SOCKS5 Proxy:"
        echo -e "${CYAN}  1)${NC} Xem danh sách proxy hiện có"
        echo -e "${CYAN}  2)${NC} Thêm một proxy user mới"
        echo -e "${CYAN}  3)${NC} Thêm ngẫu nhiên nhiều proxy"
        echo -e "${CYAN}  4)${NC} Xóa một proxy user"
        echo -e "${CYAN}  5)${NC} Xóa toàn bộ proxy user"
        echo -e "${CYAN}  6)${NC} Xuất danh sách proxy"
        echo -e "${CYAN}  7)${NC} Kiểm tra trạng thái dịch vụ"
        echo -e "${CYAN}  8)${NC} Khởi động lại dịch vụ"
        echo -e "${RED}  9)${NC} Xóa toàn bộ cấu hình server proxy & user"
        echo -e "${CYAN} 10)${NC} Thoát"
        echo ""
        
        read -p "Chọn một tùy chọn [1-10]: " option
        
        case $option in
            1) list_proxy_users ;;
            2) add_proxy_user ;;
            3) add_random_proxies ;;
            4) delete_proxy_user ;;
            5) delete_all_proxy_users ;;
            6) export_proxy_list ;;
            7) check_service_status ;;
            8) restart_service ;;
            9) uninstall_dante ;;
            10) 
                echo "Đang thoát..."
                exit 0 
                ;;
            *) 
                error_message "Lựa chọn không hợp lệ"
                pause 
                ;;
        esac
    done
}

# Hàm main
main() {
    # Kiểm tra quyền root
    check_root
    
    # Kiểm tra bash shell
    check_bash
    
    # Phát hiện hệ điều hành
    detect_os
    
    # Phát hiện giao diện mạng
    detect_network_interface
    
    # Kiểm tra Dante đã được cài đặt chưa
    if is_dante_installed; then
        # Nếu đã cài đặt, hiển thị menu quản lý
        show_main_menu
    else
        # Nếu chưa cài đặt, tiến hành cài đặt
        show_banner
        info_message "Dante SOCKS5 proxy server chưa được cài đặt."
        read -p "Bạn có muốn cài đặt Dante SOCKS5 proxy server? (y/n): " -e -i y INSTALL
        
        if [[ "$INSTALL" == 'y' || "$INSTALL" == 'Y' ]]; then
            # Cài đặt Dante
            install_dante_proxy
            
            # Sau khi cài đặt, hiển thị menu quản lý
            show_main_menu
        else
            info_message "Đã hủy cài đặt. Thoát..."
            exit 0
        fi
    fi
}

# Chạy chương trình
main
