#!/usr/bin/env bash

# scripts/delete_user.sh
#
# Script xóa một proxy user
# Tác giả: ThienTranJP

# Nạp các module cần thiết
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/user_management.sh"

# Kiểm tra quyền root
check_root

# Xóa một proxy user
delete_proxy_user
