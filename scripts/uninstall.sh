#!/usr/bin/env bash

# scripts/uninstall.sh
#
# Script gỡ cài đặt Dante SOCKS5 proxy server
# Tác giả: ThienTranJP

# Nạp các module cần thiết
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/uninstall.sh"

# Kiểm tra quyền root
check_root

# Gỡ cài đặt Dante
uninstall_dante
