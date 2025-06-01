#!/usr/bin/env bash

# scripts/delete_all_users.sh
#
# Script xóa toàn bộ proxy user
# Tác giả: ThienTranJP

# Nạp các module cần thiết
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/user_management.sh"

# Kiểm tra quyền root
check_root

# Xóa toàn bộ proxy user
delete_all_proxy_users
