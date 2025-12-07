# Dante SOCKS5 Proxy Server Manager

## Giới thiệu

Đây là bộ script quản lý Dante SOCKS5 proxy server, được thiết kế để dễ dàng cài đặt và quản lý proxy SOCKS5 trên VPS. Script hỗ trợ các hệ điều hành Debian, Ubuntu và CentOS.

Script gốc được phát triển bởi akmaslov-dev và được chỉnh sửa bởi ThienTranJP. Phiên bản hiện tại đã được cải tiến với cấu trúc module hóa để dễ dàng bảo trì và mở rộng.

## Tính năng

- Cài đặt Dante SOCKS5 proxy server tự động
- Quản lý proxy user:
  - Thêm một proxy user mới
  - Thêm ngẫu nhiên nhiều proxy
  - Xóa một proxy user
  - Xóa toàn bộ proxy user
- Giới hạn tốc độ proxy cho từng user
- Xuất danh sách proxy với định dạng IP:PORT:LOGIN:PASS
- Kiểm tra trạng thái dịch vụ
- Khởi động lại dịch vụ
- Kiểm tra hệ thống
- Gỡ cài đặt Dante SOCKS5 proxy server

## Yêu cầu hệ thống

- Hệ điều hành: Debian, Ubuntu hoặc CentOS
- Quyền root
- Bash shell

## Cài đặt

1. Tải về repository:
   ```bash
   git clone https://github.com/thien-tn/ProxyDante.git
   cd ProxyDante
   ```

2. Cấp quyền thực thi cho các file script:
   ```bash
   chmod +x install.sh
   chmod +x scripts/*.sh
   chmod +x lib/*.sh
   ```

3. Chạy script cài đặt:
   ```bash
   ./install.sh
   ```

## Cách sử dụng

Sau khi cài đặt, bạn có thể chạy lại script bất kỳ lúc nào để quản lý proxy:

```bash
./install.sh
```

Hoặc sử dụng các script riêng lẻ trong thư mục `scripts/`:

```bash
# Thêm một proxy user mới
./scripts/add_user.sh

# Thêm ngẫu nhiên nhiều proxy
./scripts/add_random_users.sh

# Xem danh sách proxy hiện có
./scripts/list_users.sh

# Xóa một proxy user
./scripts/delete_user.sh

# Xóa toàn bộ proxy user
./scripts/delete_all_users.sh

# Thay đổi giới hạn tốc độ proxy
./scripts/limit_speed.sh

# Xuất danh sách proxy
./scripts/export_proxy_list.sh

# Kiểm tra trạng thái dịch vụ
./scripts/check_status.sh

# Khởi động lại dịch vụ
./scripts/restart_service.sh

# Kiểm tra hệ thống
./scripts/system_check.sh

# Gỡ cài đặt Dante
./scripts/uninstall.sh
```

## Cấu trúc thư mục

```
ProxyDante/
├── install.sh                  # Script cài đặt chính
├── README.md                   # Tài liệu hướng dẫn
├── config/                     # Thư mục chứa các file cấu hình
│   ├── sockd.conf.template     # Template file cấu hình Dante
│   └── sockd.service.template  # Template file service systemd
├── lib/                        # Thư mục chứa các module
│   ├── common.sh               # Các hàm dùng chung
│   ├── check_environment.sh    # Kiểm tra môi trường
│   ├── install_dante.sh        # Cài đặt Dante
│   ├── setup_service.sh        # Thiết lập service
│   ├── user_management.sh      # Quản lý user proxy
│   ├── limit_speed.sh          # Giới hạn tốc độ proxy
│   └── uninstall.sh            # Gỡ cài đặt
└── scripts/                    # Thư mục chứa các script riêng lẻ
    ├── add_user.sh             # Thêm user
    ├── add_random_users.sh     # Thêm nhiều user ngẫu nhiên
    ├── delete_user.sh          # Xóa user
    ├── delete_all_users.sh     # Xóa tất cả user
    ├── list_users.sh           # Liệt kê danh sách user
    ├── limit_speed.sh          # Giới hạn tốc độ proxy
    ├── export_proxy_list.sh    # Xuất danh sách proxy
    ├── check_status.sh         # Kiểm tra trạng thái dịch vụ
    ├── restart_service.sh      # Khởi động lại dịch vụ
    ├── system_check.sh         # Kiểm tra hệ thống
    └── uninstall.sh            # Gỡ cài đặt
```

## Bảo mật

- Tất cả các proxy user được tạo với shell `/usr/sbin/nologin` để ngăn chặn đăng nhập SSH
- Mật khẩu được tạo ngẫu nhiên và mạnh
- Xác thực username/password cho proxy

## Xoá thư mục cài đặt hoàn toàn

```bash
cd
rm -r /ProxyDante
```

## Giấy phép

MIT License
