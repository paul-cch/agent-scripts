#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=mac_release.sh
source "$script_dir/mac_release.sh"

test_root=$(mktemp -d "${TMPDIR:-/tmp}/mac-release-lib-test.XXXXXX")
cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT INT TERM

MARKETING_VERSION=9.9.9
[[ "$(mac_release_version_from_zip "Example-1.2.3.app.zip")" == "1.2.3" ]]
[[ "$(mac_release_version_from_zip "Example.zip")" == "$MARKETING_VERSION" ]]

generate_log="$test_root/generate-keys"
generate_keys() {
  printf '%s\n' "$*" >"$generate_log"
}

MAC_RELEASE_SPARKLE_ACCOUNT=
mac_release_public_key_for_source keychain
[[ "$(<"$generate_log")" == "-p" ]]

MAC_RELEASE_SPARKLE_ACCOUNT=release-account
mac_release_public_key_for_source keychain
[[ "$(<"$generate_log")" == "--account release-account -p" ]]

policy_log="$test_root/policy"
syspolicy_check() {
  printf 'syspolicy:%s\n' "$*" >"$policy_log"
}
spctl() {
  return 99
}
verify_distribution_policy "/tmp/Example.app"
[[ "$(<"$policy_log")" == "syspolicy:distribution /tmp/Example.app" ]]

unset -f syspolicy_check
spctl() {
  printf 'spctl:%s\n' "$*" >"$policy_log"
}
verify_distribution_policy "/tmp/Example.app"
[[ "$(<"$policy_log")" == "spctl:--assess --type execute --verbose /tmp/Example.app" ]]

mkdir "$test_root/changelog"
printf '# Changelog\n\n## [1.2.3] - 2026-07-23\n\n- Fixed.\n' >"$test_root/changelog/CHANGELOG.md"
(
  cd "$test_root/changelog"
  ensure_changelog_finalized 1.2.3
)

printf 'mac release library tests passed\n'
