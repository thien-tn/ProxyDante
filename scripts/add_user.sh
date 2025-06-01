#!/usr/bin/env bash

# scripts/add_user.sh
#
# Script thêm một proxy user mới
# Tác giả: ThienTranJP

# Nạp các module cần thiết
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/user_management.sh"

# Kiểm tra quyền root
check_root

# Thêm proxy user mới
add_proxy_user
