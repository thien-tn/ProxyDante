#!/usr/bin/env bash

# scripts/list_users.sh
#
# Script hiển thị danh sách proxy user
# Tác giả: ThienTranJP

# Nạp các module cần thiết
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/user_management.sh"

# Kiểm tra quyền root
check_root

# Hiển thị danh sách proxy user
list_proxy_users
