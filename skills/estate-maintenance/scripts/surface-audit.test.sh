#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
output=$("$script_dir/surface-audit.sh" /)

grep -q $'^observed_at\t[0-9][0-9][0-9][0-9]-' <<<"$output"
for field in host os kernel architecture disk memory; do
  grep -q "^${field}"$'\t' <<<"$output"
done

if "$script_dir/surface-audit.sh" /definitely-not-an-estate-path >/dev/null 2>&1; then
  printf 'missing probe path unexpectedly passed\n' >&2
  exit 1
fi

printf 'estate surface audit tests passed\n'
