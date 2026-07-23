#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/estate-repo-audit-test.XXXXXX")
cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT INT TERM

git init --bare "$test_root/remote.git" >/dev/null
git init "$test_root/seed" >/dev/null
git -C "$test_root/seed" config user.name "Estate Test"
git -C "$test_root/seed" config user.email "estate@example.invalid"
printf 'one\n' >"$test_root/seed/file.txt"
git -C "$test_root/seed" add file.txt
git -C "$test_root/seed" commit -m init >/dev/null
git -C "$test_root/seed" branch -M main
git -C "$test_root/seed" remote add origin "$test_root/remote.git"
git -C "$test_root/seed" push -u origin main >/dev/null
git --git-dir="$test_root/remote.git" symbolic-ref HEAD refs/heads/main
git clone "$test_root/remote.git" "$test_root/projects/demo" >/dev/null

: >"$test_root/cwds"
output=$(ESTATE_ACTIVE_CWDS_FILE="$test_root/cwds" "$script_dir/repo-sync-audit.sh" "$test_root/projects")
grep -q $'\tcurrent$' <<<"$output"
grep -q $'^repo\t.*/demo\t[0-9][0-9][0-9][0-9]-' <<<"$output"

output=$(ESTATE_ACTIVE_CWDS_FILE="$test_root/cwds" "$script_dir/repo-sync-audit.sh" "$test_root/projects/demo")
grep -q $'\tcurrent$' <<<"$output"

printf 'two\n' >>"$test_root/seed/file.txt"
git -C "$test_root/seed" commit -am update >/dev/null
git -C "$test_root/seed" push >/dev/null
git -C "$test_root/projects/demo" fetch >/dev/null
output=$(ESTATE_ACTIVE_CWDS_FILE="$test_root/cwds" "$script_dir/repo-sync-audit.sh" "$test_root/projects")
grep -q $'\tfast-forward-available$' <<<"$output"

printf 'local\n' >"$test_root/projects/demo/local.txt"
output=$(ESTATE_ACTIVE_CWDS_FILE="$test_root/cwds" "$script_dir/repo-sync-audit.sh" "$test_root/projects")
grep -q $'\tinspect-dirty$' <<<"$output"

printf '#!/bin/sh\nexit 17\n' >"$test_root/failing-lsof"
chmod +x "$test_root/failing-lsof"
output=$(ESTATE_LSOF_BIN="$test_root/failing-lsof" "$script_dir/repo-sync-audit.sh" "$test_root/projects/demo")
grep -q $'\tunknown\tno\t[0-9].*\tskip-active-unknown$' <<<"$output"

output=$(ESTATE_ACTIVE_CWDS_FILE="$test_root/cwds" "$script_dir/repo-sync-audit.sh" "$test_root/projects/demo" upstream/main)
grep -q $'\tmissing:upstream/main\t' <<<"$output"
grep -q $'\tinspect-dirty$' <<<"$output"

printf 'estate repo audit tests passed\n'
