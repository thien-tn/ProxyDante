#!/usr/bin/env bash

# scripts/export_proxy_list.sh
#
# Script xuất danh sách proxy
# Tác giả: ThienTranJP

# Nạp các module cần thiết
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/user_management.sh"

# Kiểm tra quyền root
check_root

# Xuất danh sách proxy
export_proxy_list
