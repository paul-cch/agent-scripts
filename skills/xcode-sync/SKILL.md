---
name: xcode-sync
description: "Xcode build inventory and sync: archive provenance, compatibility, rollback, selection, and first launch."
---

# Xcode Sync

Inventory or synchronize exact Xcode builds across explicitly approved Macs and
VMs. Use `$remote-mac` or `$vm-lab` for target identity and access.

## Inventory

Run locally or over SSH:

```bash
skills/xcode-sync/scripts/xcode-host-inventory.sh
ssh -o RequestTTY=no -o RemoteCommand=none HOST 'bash -s' \
  < skills/xcode-sync/scripts/xcode-host-inventory.sh
```

Treat unreachable hosts as pending. Verify hostname, user, hardware UUID,
macOS build, architecture, selected developer directory, and every Xcode
marketing version plus `ProductBuildVersion`. The inventory helper emits
`unknown` or `not-selected` rather than treating missing identity as proof;
keep those rows pending.

## Source Proof

Prefer an existing downloaded `.xip`; do not redownload without asking.

```bash
pkgutil --check-signature "$archive"
shasum -a 256 "$archive"
stage=$(mktemp -d /tmp/xcode.XXXXXX)
trap 'rm -rf "$stage"' EXIT
(cd "$stage" && xip --expand "$archive")
```

Require an Apple signature. Inspect `CFBundleShortVersionString`,
`ProductBuildVersion`, `LSMinimumSystemVersion`, architecture, and
`xcodebuild -version`. Build identity wins over a marketing label.

Resolve current compatibility from the archive and authoritative Apple sources.
Do not embed a durable Xcode/macOS version matrix in this skill.

## Change Gate

Archive transfer is reversible; installation, replacement, selection, license
acceptance, and deletion require explicit current approval for the named hosts.

- Transfer the signed archive and verify its SHA on each destination.
- Stage and validate the new app before moving an existing channel.
- Keep explicit stable, prerelease, and previous-major slots only when the user
  requests that policy.
- Preserve `xcode-select` unless the request names a switch.
- Keep a rollback path until signature, version, selection, and first-launch
  proof pass.
- Never delete an unexpected app or old archive automatically.

## Verification

For each installed app:

```bash
DEVELOPER_DIR="$app/Contents/Developer" xcodebuild -version
codesign --verify --deep --strict "$app"
DEVELOPER_DIR="$app/Contents/Developer" xcodebuild -checkFirstLaunchStatus
```

Report installation and readiness separately. Finish with a host matrix:
macOS build, architecture, desired Xcode build, installed path, selected path,
signature, first-launch state, rollback state, and pending reason. Record the
exact Xcode build in Mac release receipts.
