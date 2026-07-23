#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/xcode-inventory-test.XXXXXX")
cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT INT TERM

mkdir -p \
  "$test_root/bin" \
  "$test_root/apps/Xcode.app/Contents/Developer" \
  "$test_root/apps/Xcode-beta.app/Contents/Developer"

for command in hostname id sw_vers uname ioreg xcode-select plutil; do
  touch "$test_root/bin/$command"
  chmod +x "$test_root/bin/$command"
done

printf '#!/bin/sh\nprintf "test-mac\\n"\n' >"$test_root/bin/hostname"
printf '#!/bin/sh\nprintf "fixture-user\\n"\n' >"$test_root/bin/id"
printf '#!/bin/sh\ncase "$1" in -productVersion) echo 15.5;; -buildVersion) echo 24F74;; esac\n' >"$test_root/bin/sw_vers"
printf '#!/bin/sh\nprintf "arm64\\n"\n' >"$test_root/bin/uname"
printf '#!/bin/sh\n[ "${TEST_MISSING_IDENTITY:-0}" = 1 ] || printf "    \\"IOPlatformUUID\\" = \\"TEST-UUID\\"\\n"\n' >"$test_root/bin/ioreg"
printf '#!/bin/sh\n[ "${TEST_MISSING_IDENTITY:-0}" = 1 ] && exit 1\nprintf "%%s/Contents/Developer\\n" "$TEST_XCODE_APP"\n' >"$test_root/bin/xcode-select"
printf '#!/bin/sh\ncase "$2:$6" in CFBundleShortVersionString:*Xcode-beta.app*) echo 26.0;; ProductBuildVersion:*Xcode-beta.app*) echo 17A1;; CFBundleShortVersionString:*) echo 16.4;; ProductBuildVersion:*) echo 16F6;; LSMinimumSystemVersion:*) echo 15.0;; esac\n' >"$test_root/bin/plutil"
chmod +x "$test_root/bin/"*

output=$(
  PATH="$test_root/bin:$PATH" \
    TEST_XCODE_APP="$test_root/apps/Xcode.app" \
    XCODE_APP_ROOTS="$test_root/apps" \
    "$script_dir/xcode-host-inventory.sh"
)

grep -q $'^host\ttest-mac\tfixture-user\tTEST-UUID\t15.5\t24F74\tarm64\t.*/Xcode.app\t[0-9][0-9][0-9][0-9]-' <<<"$output"
grep -q $'Xcode.app\t16.4\t16F6\t15.0\tyes$' <<<"$output"
grep -q $'Xcode-beta.app\t26.0\t17A1\t15.0\tno$' <<<"$output"

output=$(
  PATH="$test_root/bin:$PATH" \
    TEST_MISSING_IDENTITY=1 \
    XCODE_APP_ROOTS="$test_root/apps" \
    "$script_dir/xcode-host-inventory.sh"
)
grep -q $'^host\ttest-mac\tfixture-user\tunknown\t15.5\t24F74\tarm64\tnot-selected\t' <<<"$output"
grep -q $'Xcode.app\t16.4\t16F6\t15.0\tno$' <<<"$output"
printf 'xcode inventory tests passed\n'
