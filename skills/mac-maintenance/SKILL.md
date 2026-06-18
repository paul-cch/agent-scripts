---
name: mac-maintenance
description: "Mac upkeep: read-only health triage, cleanup planning, and explicitly approved maintenance."
---

# Mac Maintenance

Use when Paul's machine needs cleanup, maintenance, performance diagnosis, or package/repo refresh.

Default to read-only diagnosis. Do not delete, unload, kill, upgrade, pull, empty
Trash, change login items, or mutate system/app state unless Paul explicitly
approved that named action.

Preserve intentional utilities unless live evidence shows a concrete problem. Do
not treat third-party menu bar apps, launch agents, or background helpers as
clutter just because they exist. Trace suspicious processes, helpers, launch
items, or daemons back to an owning app, bundle, plist, package, or exact path
before recommending action. If something is root-owned or system-managed, say so
and recommend the correct admin, app, Finder, or System Settings path instead of
blind shell deletion.

## Run

1. Read-only health snapshot:

```bash
df -h /System/Volumes/Data
memory_pressure
pmset -g batt
pmset -g assertions | sed -n '1,120p'
top -l 1 -o cpu | head -60
```

2. Targeted live ownership checks:

```bash
ps axro pid,ppid,user,%cpu,%mem,rss,etime,args |
  awk 'BEGIN{IGNORECASE=1} /Codex|Electron|WindowServer|mds|mdworker|fileprovider|SeaDrive|Safari|WebKit|Chrome|Notion|Raycast|WithSecure|Cisco|Duo|NordVPN|npx|npm exec|node/ {print}'

find ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons \
  -maxdepth 1 -name '*.plist' -print 2>/dev/null | sort
```

Use focused `du -sh` checks for known high-signal targets. Avoid broad home or
Library scans unless Paul asked for a deep storage audit. For performance
findings, separate likely root causes from secondary symptoms before
recommending fixes: high `WindowServer`, browser/WebKit, Electron, Spotlight, or
file-provider CPU can be driven by UI churn, builds, sync loops, storage
analysis, or scanner work. For SeaDrive/FileProvider state, prefer
`fileproviderctl evaluate` over broad `du` walks; if a cloud-backed size scan
stalls or becomes a top offender, stop it and switch back to metadata/status
checks.

3. Classify findings:

- Safe Cleanup Candidate: user-owned caches or disposable artifacts with exact paths and no active app dependency.
- Needs Review: app state, cloud/file-provider caches, active SQLite databases, Xcode/device/simulator state, Downloads, or anything with sync/history tradeoffs.
- Expected: traced apps, menu bar tools, launch agents, or system services that are functioning normally.

4. Only after explicit approval, run the approved mutation set.

Homebrew:

```bash
brew update && brew upgrade
```

Repos under `~/Projects`:

```bash
for repo in ~/Projects/*/.git; do
  dir=${repo:h}
  git -C "$dir" status --short --branch
  git -C "$dir" pull --ff-only
done
```

Skip dirty repos unless the user explicitly asked to handle them. Report skipped paths.

Empty Trash:

```bash
osascript -e 'tell application "Finder" to empty trash'
```

5. Finish with terse counts:

- read-only evidence checked
- mutations approved and performed
- cleanup: removed / skipped / needs review
- brew: upgraded / already current / skipped
- repos: pulled / skipped / failed
- trash: emptied / skipped / failed
