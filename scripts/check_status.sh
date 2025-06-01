#!/usr/bin/env bash

# scripts/check_status.sh
#
# Script kiểm tra trạng thái của Dante SOCKS5 proxy server
# Tác giả: ThienTranJP

# Nạp các module cần thiết
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/setup_service.sh"

# Kiểm tra quyền root
check_root

# Kiểm tra trạng thái dịch vụ
check_service_status
