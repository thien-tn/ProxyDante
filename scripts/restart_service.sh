#!/usr/bin/env bash

# scripts/restart_service.sh
#
# Script khởi động lại dịch vụ Dante SOCKS5 proxy server
# Tác giả: ThienTranJP

# Nạp các module cần thiết
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/setup_service.sh"

# Kiểm tra quyền root
check_root

# Khởi động lại dịch vụ
restart_service
