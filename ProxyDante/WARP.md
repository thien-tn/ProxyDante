# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Overview
Bash-based tooling to install and manage the Dante SOCKS5 proxy on Linux (Debian/Ubuntu/CentOS). The entrypoint `install.sh` sources modular utilities in `lib/`, generates config from templates in `config/`, and creates/controls a `systemd` service `sockd`. Convenience wrappers in `scripts/` call into the same library functions for one-off admin tasks.

Important runtime facts
- Requires root and Bash on a Linux host. Designed to be run on the target server (not on macOS/Windows). If you’re developing from Windows/macOS, use SSH or WSL to a Linux VM.
- Default Dante port is asked interactively; defaults to 1080 when not set.
- Proxy credentials are system users with shell `/usr/sbin/nologin`. A plain-text inventory of created proxies lives at `/etc/dante/proxy_list.txt`.
- Generated files: `/etc/sockd.conf` from `config/sockd.conf.template` and `/etc/systemd/system/sockd.service` from `config/sockd.service.template`.

## Common commands
All commands below assume you’re on a Linux host with root privileges.

- Initial setup (make scripts executable)
  ```bash path=null start=null
  chmod +x install.sh lib/*.sh scripts/*.sh
  ```

- Install and open the interactive manager (compiles Dante if needed, generates config/service)
  ```bash path=null start=null
  sudo ./install.sh
  ```

- One-off admin tasks (wrappers around `lib/` functions)
  ```bash path=null start=null
  # Add one proxy user (prompts for username/password)
  sudo ./scripts/add_user.sh

  # Create N random proxy users (prompts for N)
  sudo ./scripts/add_random_users.sh

  # List all proxies (reads /etc/dante/proxy_list.txt; recreates with placeholders if empty)
  sudo ./scripts/list_users.sh

  # Delete a single proxy user (prompts for username)
  sudo ./scripts/delete_user.sh

  # Delete ALL proxy users and clear the proxy list
  sudo ./scripts/delete_all_users.sh

  # Export proxies to ./proxy_list.txt
  sudo ./scripts/export_proxy_list.sh

  # Service status / restart
  sudo ./scripts/check_status.sh
  sudo ./scripts/restart_service.sh

  # Uninstall Dante, users, config, and service
  sudo ./scripts/uninstall.sh
  ```

- Service debugging (outside the wrappers)
  ```bash path=null start=null
  sudo systemctl status sockd
  sudo journalctl -xeu sockd.service
  sudo systemctl restart sockd
  ```

- Linting and basic checks (no test suite exists)
  ```bash path=null start=null
  # Syntax check a single file
  bash -n lib/user_management.sh

  # Lint all scripts with shellcheck (install via apt/yum as needed)
  shellcheck install.sh lib/*.sh scripts/*.sh

  # Format with shfmt (show diff, then write)
  shfmt -d .
  shfmt -w .
  ```

## High-level architecture
- Entry point: `install.sh`
  - Sources `lib/common.sh`, `lib/check_environment.sh`, `lib/install_dante.sh`, `lib/setup_service.sh`, `lib/user_management.sh`, `lib/uninstall.sh`.
  - Flow: environment checks → OS/network detection → if Dante present, show interactive menu; else perform install (dependencies → compile Dante from tarball or download → create `/etc/sockd.conf` → create `systemd` service → create N random users) → show menu.

- Library modules (responsibilities)
  - `lib/common.sh`: global paths, ANSI colors, status helpers; helpers for install state (`is_dante_installed`), user discovery (`get_proxy_users`), random string generation, IP/port helpers, firewall opening.
  - `lib/check_environment.sh`: root/bash checks; OS detection (sets `OStype`); detects primary network interface (`interface`) and host IP (`hostname`); dependency probing.
  - `lib/install_dante.sh`: installs build deps; compiles Dante 1.4.4 from local `dante-1.4.4.tar.gz` or downloads a fallback; writes `/etc/sockd.conf` from `config/sockd.conf.template` substituting `%INTERFACE%` and `%PORT%`; creates random users; orchestrator `install_dante_proxy`.
  - `lib/setup_service.sh`: ensures `sockd` binary is available/executable; checks dynamic libs; writes `sockd.service` from template; `systemctl` helpers to start/restart/status/remove the service.
  - `lib/user_management.sh`: maintains `/etc/dante/proxy_list.txt` (ensure/create, add/update/remove entries); user CRUD against system accounts; exports proxy list to `./proxy_list.txt`.
  - `lib/uninstall.sh`: stops/disables service; removes config, binary, and proxy users; clears `/etc/dante/proxy_list.txt`.

- Templates in `config/`
  - `sockd.conf.template` → `/etc/sockd.conf` via `sed` replacing `%INTERFACE%` and `%PORT%`.
  - `sockd.service.template` → `/etc/systemd/system/sockd.service`.

- Thin wrappers in `scripts/`
  - Each wrapper sources `lib/common.sh` and exactly one feature module, checks root, and calls a single exported function (e.g., `add_proxy_user`, `delete_proxy_user`, `restart_service`). They exist so operators don’t need the interactive menu for routine tasks.

## Important quirks to be aware of
- OS type constant mismatch: `lib/check_environment.sh` exports `OStype="deb"` for Debian/Ubuntu, but `lib/install_dante.sh` checks for `"debian"`/`"ubuntu"`. On Debian/Ubuntu this skips the `apt-get` dependency installation paths. Aligning these values fixes package install branches.
- Missing module referenced by wrapper: `scripts/limit_speed.sh` sources `lib/limit_speed.sh`, which is not present in this repo. The wrapper will fail until that module is added.
- Undefined helper in `scripts/system_check.sh`: calls `get_ip`, which isn’t defined; `lib/common.sh` provides `get_server_ip` and `lib/check_environment.sh` exports `hostname` with the IP. Replace `get_ip` with one of those to avoid runtime errors.
- Duplicate `is_port_in_use` implementations appear in `lib/common.sh` and `lib/check_environment.sh`. Prefer the `ss`/`netstat`-aware version in `common.sh` to avoid relying solely on `netstat`.
- `open_firewall_port` is defined but not invoked during install. If you expect closed firewalls (UFW/iptables), ensure the chosen proxy port is opened post-install.

## Bandwidth Limiting (tc HTB)
Module `lib/limit_speed.sh` provides bandwidth control using Linux Traffic Control (tc) with HTB qdisc.

### Quick setup
```bash path=null start=null
# Via interactive menu
sudo ./install.sh
# Choose option 7: Giới hạn băng thông (Bandwidth Limiting)

# Or via standalone script
sudo ./scripts/limit_speed.sh
```

### Key concepts
- **Global rate/ceil**: Total bandwidth allocated to Dante proxy (default: 100mbit)
- **Per-IP rate/ceil**: Bandwidth per client IP (default: 10mbit rate, 20mbit ceil for burst)
- **SFQ (Stochastic Fair Queuing)**: Ensures fair distribution among connections within same class
- **IFB (Intermediate Functional Block)**: Virtual interface for ingress shaping

### Configuration file
`/etc/dante/bandwidth.conf` stores:
- `TC_INTERFACE`: Network interface for tc rules
- `GLOBAL_RATE`, `GLOBAL_CEIL`: Total bandwidth limits
- `PER_IP_RATE`, `PER_IP_CEIL`: Per-client-IP limits
- `CUSTOM_IP_LIMITS`: Array of custom per-IP limits (format: `IP:RATE:CEIL`)

### Commands
```bash path=null start=null
# Apply traffic control rules
source lib/common.sh && source lib/limit_speed.sh && setup_traffic_control

# View current tc status
tc qdisc show dev eth0
tc class show dev eth0
tc -s class show dev eth0  # with statistics

# Clear all tc rules
source lib/common.sh && source lib/limit_speed.sh && remove_traffic_control
```

### Auto-apply on boot
Option 9 in bandwidth menu creates `dante-tc.service` which applies tc rules after `sockd.service` starts.

### Architecture
```
                    ┌─────────────────────────────────────┐
                    │         HTB Root (1:)               │
                    │         rate: GLOBAL_RATE           │
                    └─────────────┬───────────────────────┘
                                  │
            ┌─────────────────────┼─────────────────────┐
            │                     │                     │
   ┌────────▼────────┐   ┌────────▼────────┐   ┌───────▼───────┐
   │  Class 1:10     │   │  Class 1:20     │   │  Class 1:30   │
   │  Dante traffic  │   │  Per-IP default │   │  Other (low)  │
   │  prio 1         │   │  prio 2         │   │  prio 3       │
   └────────┬────────┘   └─────────────────┘   └───────────────┘
            │
   ┌────────▼────────┐
   │  SFQ qdisc      │
   │  Fair queuing   │
   └─────────────────┘
```

## Pointers from README (condensed)
- Supported OS: Debian, Ubuntu, CentOS; requires root and Bash.
- After installation you can re-run `./install.sh` any time to manage users, export lists, check status, restart, or uninstall.
- Proxy list format is `IP:PORT:LOGIN:PASS` and is persisted at `/etc/dante/proxy_list.txt` and exportable to `./proxy_list.txt`.
