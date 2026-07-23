#!/usr/bin/env bash
set -euo pipefail

root=${1:-"$HOME/Projects"}
compare_ref=${ESTATE_COMPARE_REF:-${2:-}}
if [[ ! -d "$root" ]]; then
  printf 'project root not found: %s\n' "$root" >&2
  exit 2
fi
root=$(cd "$root" && pwd -P)
observed_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

tmp=$(mktemp -d "${TMPDIR:-/tmp}/estate-repo-audit.XXXXXX")
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT INT TERM

active_probe=unknown
if [[ -n "${ESTATE_ACTIVE_CWDS_FILE:-}" && -r "$ESTATE_ACTIVE_CWDS_FILE" ]]; then
  cp "$ESTATE_ACTIVE_CWDS_FILE" "$tmp/cwds"
  active_probe=ok
elif command -v "${ESTATE_LSOF_BIN:-lsof}" >/dev/null 2>&1 &&
  (
    "${ESTATE_LSOF_BIN:-lsof}" -a -u "$USER" -d cwd -Fn 2>/dev/null |
      sed -n 's/^n//p' >"$tmp/cwds"
  ) 2>/dev/null; then
  active_probe=ok
else
  : >"$tmp/cwds"
fi

: >"$tmp/repos"
: >"$tmp/seen"
record_repo() {
  local candidate=$1 physical
  physical=$(cd "$candidate" && pwd -P)
  if ! grep -Fqx "$physical" "$tmp/seen"; then
    printf '%s\n' "$physical" >>"$tmp/seen"
    printf '%s\0' "$physical" >>"$tmp/repos"
  fi
}

discover_repos() {
  local dir=$1
  local depth=$2
  local child

  for child in "$dir"/*; do
    [[ -d "$child" ]] || continue
    case "${child##*/}" in
      .*|node_modules|vendor|build|dist|DerivedData) continue ;;
    esac
    if [[ -e "$child/.git" ]]; then
      record_repo "$child"
    elif ((depth < 2)); then
      discover_repos "$child" "$((depth + 1))"
    fi
  done
}
if [[ -e "$root/.git" ]]; then
  record_repo "$root"
else
  discover_repos "$root" 0
fi

printf 'repo\tpath\tobserved_at\tbranch\tcached_ref\tdirty\tactive\tgit_lock\tahead\tbehind\tdecision\n'
while IFS= read -r -d '' repo; do
  branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'DETACHED')
  if [[ -n "$compare_ref" ]]; then
    if git -C "$repo" rev-parse --verify --quiet "$compare_ref^{commit}" >/dev/null; then
      cached_ref=$compare_ref
    else
      cached_ref="missing:$compare_ref"
    fi
  else
    cached_ref=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || printf '-')
  fi

  dirty=unknown
  if state=$(GIT_OPTIONAL_LOCKS=0 git -C "$repo" status --porcelain=v2 --untracked-files=normal 2>/dev/null); then
    dirty=no
    [[ -n "$state" ]] && dirty=yes
  fi

  active=unknown
  if [[ "$active_probe" == ok ]]; then
    active=no
    while IFS= read -r cwd; do
      case "$cwd/" in
        "$repo/"*) active=yes; break ;;
      esac
    done <"$tmp/cwds"
  fi

  git_lock=no
  git_dir=$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null || true)
  common_dir=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
  if [[ -z "$git_dir" || -z "$common_dir" ]]; then
    git_lock=unknown
  elif lock_path=$(find "$git_dir" "$common_dir" -name '*.lock' -print -quit 2>/dev/null); then
    [[ -n "$lock_path" ]] && git_lock=yes
  else
    git_lock=unknown
  fi

  ahead=unknown
  behind=unknown
  if [[ "$cached_ref" != - && "$cached_ref" != missing:* ]] &&
    counts=$(git -C "$repo" rev-list --left-right --count "HEAD...$cached_ref" 2>/dev/null); then
    read -r ahead behind <<<"$counts"
  fi

  decision=inspect-unknown
  if [[ "$git_lock" != no ]]; then
    decision=skip-git-lock
  elif [[ "$active" == yes ]]; then
    decision=skip-active
  elif [[ "$active" == unknown ]]; then
    decision=skip-active-unknown
  elif [[ "$dirty" != no ]]; then
    decision=inspect-dirty
  elif [[ "$branch" == DETACHED ]]; then
    decision=inspect-detached
  elif [[ "$cached_ref" == - ]]; then
    decision=inspect-no-upstream
  elif [[ "$cached_ref" == missing:* ]]; then
    decision=inspect-missing-ref
  elif [[ "$ahead" == 0 && "$behind" == 0 ]]; then
    decision=current
  elif [[ "$ahead" == 0 && "$behind" =~ ^[1-9][0-9]*$ ]]; then
    decision=fast-forward-available
  elif [[ "$ahead" =~ ^[1-9][0-9]*$ && "$behind" == 0 ]]; then
    decision=local-ahead
  elif [[ "$ahead" =~ ^[1-9][0-9]*$ && "$behind" =~ ^[1-9][0-9]*$ ]]; then
    decision=diverged
  fi

  printf 'repo\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$repo" "$observed_at" "$branch" "$cached_ref" "$dirty" "$active" "$git_lock" "$ahead" "$behind" "$decision"
done <"$tmp/repos"
