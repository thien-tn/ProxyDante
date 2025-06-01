#!/usr/bin/env bash

# scripts/limit_speed.sh
#
# Script giới hạn tốc độ proxy
# Tác giả: ThienTranJP

# Nạp các module cần thiết
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/limit_speed.sh"

# Kiểm tra quyền root
check_root

# Thay đổi giới hạn tốc độ proxy
change_speed_limit
