---
name: remote-mac
description: "Remote Macs: homelab/source/runtime checks, SSH, OpenClaw."
---

# Remote Mac

Use only after checking the current Homelab/OpenClaw docs and live host state.

## Paul's Topology

Known routing principles:
- Keep local source repos, homelab host/runtime, and live assistant surfaces distinct.
- Prefer configured SSH aliases or repo docs over remembered hostnames.
- Verify host identity before running commands.
- Do not install, restart, unload, or mutate services without explicit approval.

Expected source areas:
- `~/Projects/Homelab/homelab-clean`
- OpenClaw source/runtime docs inside that repo
