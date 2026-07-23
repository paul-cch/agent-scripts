#!/usr/bin/env bash
set -euo pipefail

observed_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
host_name=$(hostname 2>/dev/null || true)
user_name=$(id -un 2>/dev/null || true)
macos_version=$(sw_vers -productVersion 2>/dev/null || true)
macos_build=$(sw_vers -buildVersion 2>/dev/null || true)
architecture=$(uname -m 2>/dev/null || true)
hardware_uuid=$(
  ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null |
    awk -F'"' '/IOPlatformUUID/ { print $4; exit }'
)
selected_developer=$(xcode-select -p 2>/dev/null || true)
selected_app=not-selected
if [[ -n "$selected_developer" ]]; then
  selected_app=${selected_developer%/Contents/Developer}
fi

host_name=${host_name:-unknown}
user_name=${user_name:-unknown}
macos_version=${macos_version:-unknown}
macos_build=${macos_build:-unknown}
architecture=${architecture:-unknown}
hardware_uuid=${hardware_uuid:-unknown}

printf 'host\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$host_name" "$user_name" "$hardware_uuid" "$macos_version" "$macos_build" "$architecture" "$selected_app" "$observed_at"

if [[ -n "${XCODE_APP_ROOTS:-}" ]]; then
  old_ifs=$IFS
  IFS=:
  read -r -a app_roots <<<"$XCODE_APP_ROOTS"
  IFS=$old_ifs
else
  app_roots=(/Applications "$HOME/Applications")
fi

shopt -s nullglob
for root in "${app_roots[@]}"; do
  [[ -d "$root" ]] || continue
  for app in "$root"/Xcode*.app; do
    [[ -d "$app" ]] || continue
    version=$(plutil -extract CFBundleShortVersionString raw -o - "$app/Contents/Info.plist" 2>/dev/null || printf '?')
    build=$(plutil -extract ProductBuildVersion raw -o - "$app/Contents/version.plist" 2>/dev/null || printf '?')
    minimum=$(plutil -extract LSMinimumSystemVersion raw -o - "$app/Contents/Info.plist" 2>/dev/null || printf '?')
    selected=no
    [[ "$selected_app" != not-selected && "$app" == "$selected_app" ]] && selected=yes
    printf 'xcode\t%s\t%s\t%s\t%s\t%s\n' "$app" "$version" "$build" "$minimum" "$selected"
  done
done
