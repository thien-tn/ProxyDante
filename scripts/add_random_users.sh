#!/usr/bin/env bash

# scripts/add_random_users.sh
#
# Script thêm ngẫu nhiên nhiều proxy user
# Tác giả: ThienTranJP

# Nạp các module cần thiết
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/user_management.sh"

# Kiểm tra quyền root
check_root

# Thêm ngẫu nhiên nhiều proxy
add_random_proxies
