---
summary: "Paul-specific migration notes for the agent-scripts fork"
read_when:
  - Porting Peter-specific skills, tools, accounts, or OpenClaw routing.
---

# Paul Adaptation Notes

## Target

This fork is Paul's canonical Codex setup.

Profile:
- unified Paul machine profile
- local Mac first
- UCL/student work supported
- OpenClaw/homelab concepts ported to Paul's infrastructure
- Codex only; Claude setup left untouched

## Fork Policy

- `origin`: Paul's fork
- `upstream`: `https://github.com/steipete/agent-scripts.git`
- Pull from upstream deliberately.
- Keep Paul-specific machine rules in this fork rather than local-only patches.

## Tooling Policy

- `active`: installed and verified on Paul's machine
- `optional`: useful but not required
- `missing`: referenced but not installed
- `ported later`: Peter-specific workflow preserved as notes until Paul equivalent exists
- `delete candidate`: not useful for Paul after review

## Secret Policy

1Password is optional, not mandatory. Skills may recommend `op` when configured, but must not assume `op`, a service account token, vault names, item titles, or account names.

## OpenClaw Policy

Port concepts, not Peter's topology. Do not use Peter hostnames, Peter accounts, Molty assumptions, or `/Users/steipete` paths as defaults.

## Tool Decisions

- `gh`: active.
- `gws`: active.
- `peekaboo`: active binary present; permissions must be checked live.
- `mcporter`: active binary present.
- `video-transcript-downloader`: candidate; requires `npm ci`.
- `op`: optional.
- `rem`/`things`: missing; decide later.
- Peter social/media tools: port later one by one.

## Symlink Decisions

- `autoreview`: public OpenClaw shared skill; use `../agent-skills`.
- `handoff`: public OpenClaw shared skill; use `../agent-skills`.
- `birdclaw`: decision pending.
- `discrawl`: decision pending.
- `gog`: decision pending.
- `imsg`: decision pending.
- `slacrawl`: decision pending.
- `wacli`: decision pending.
- `wacrawl`: decision pending.

