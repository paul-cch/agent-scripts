#!/usr/bin/env bash
set -euo pipefail

probe_path=${1:-/}
if [[ ! -e "$probe_path" ]]; then
  printf 'probe path not found: %s\n' "$probe_path" >&2
  exit 2
fi
observed_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

host=$(hostname)
kernel=$(uname -sr)
architecture=$(uname -m)

if command -v sw_vers >/dev/null 2>&1; then
  os=$(sw_vers -productName)
  os_version=$(sw_vers -productVersion)
elif [[ -r /etc/os-release ]]; then
  os=$(awk -F= '$1 == "NAME" { gsub(/^"|"$/, "", $2); print $2; exit }' /etc/os-release)
  os_version=$(awk -F= '$1 == "VERSION_ID" { gsub(/^"|"$/, "", $2); print $2; exit }' /etc/os-release)
else
  os=$(uname -s)
  os_version=unknown
fi

read -r disk_blocks disk_used disk_available disk_percent disk_mount < <(
  df -Pk "$probe_path" | awk 'NR == 2 { print $2, $3, $4, $5, $6 }'
)

memory_total_kib=unknown
memory_available_kib=unknown
if [[ -r /proc/meminfo ]]; then
  memory_total_kib=$(awk '$1 == "MemTotal:" { print $2 }' /proc/meminfo)
  memory_available_kib=$(awk '$1 == "MemAvailable:" { print $2 }' /proc/meminfo)
elif command -v sysctl >/dev/null 2>&1; then
  memory_bytes=$(sysctl -n hw.memsize 2>/dev/null || true)
  if [[ "$memory_bytes" =~ ^[0-9]+$ ]]; then
    memory_total_kib=$((memory_bytes / 1024))
  fi
fi

printf 'observed_at\t%s\n' "$observed_at"
printf 'host\t%s\n' "$host"
printf 'os\t%s\t%s\n' "${os:-unknown}" "${os_version:-unknown}"
printf 'kernel\t%s\n' "$kernel"
printf 'architecture\t%s\n' "$architecture"
printf 'disk\tpath=%s\tmount=%s\tblocks_kib=%s\tused_kib=%s\tavailable_kib=%s\tused_percent=%s\n' \
  "$probe_path" "$disk_mount" "$disk_blocks" "$disk_used" "$disk_available" "$disk_percent"
printf 'memory\ttotal_kib=%s\tavailable_kib=%s\n' "$memory_total_kib" "$memory_available_kib"
