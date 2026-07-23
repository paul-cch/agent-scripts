---
name: estate-maintenance
description: "Homelab and Mac estate audits: proof surfaces, host health, repo drift, and approved maintenance."
---

# Estate Maintenance

Audit and maintain Paul's estate without collapsing source, host, runtime, live
config, or external-service truth into one status claim.

## Safety Contract

- Default to read-only inventory. A maintenance request does not implicitly
  authorize package upgrades, repo updates, service restarts, cleanup, deploys,
  or live-config writes.
- Name the target surface before every mutation and require current authority
  for that surface.
- Audit independent hosts in parallel when safe; mutate one surface at a time.
- Treat unreachable, unauthenticated, stale, or unverified surfaces as
  `pending`, never current.
- Preserve dirty worktrees, active processes, Git locks, runtime-authored state,
  and unknown files. Do not stash, reset, clean, rebase, or fast-forward them.
- Keep receipts content-silent where secrets, private payloads, or live config
  are involved.

## Surface Model

Keep separate rows for:

| Surface | Typical authority |
|---|---|
| `repo` | current source checkout and GitHub |
| `agent-workstation` | VM 109 operator checkout and tools |
| `host` | `iris-m1` and host-side deployment state |
| `runtime` | LXC 111 OpenClaw runtime |
| `live-config` | mutable OpenClaw configuration |
| `memory-core` | VM 108 and AgentMemory-compatible state |
| `hermes-photon` | operator, iMessage, and delivery proof |
| `mac` | approved Mac or VM build/runtime host |
| `external` | connector-backed service state |

Use the owning repo docs and narrower skills for each surface. Prefer
`$homelab-harness`, `$remote-mac`, `$vm-lab`, and `$mac-maintenance` where
available. A repo receipt cannot prove a runtime or external row.

## Audit

1. Read the target repo's operating model, inventory, and nearest `AGENTS.md`.
2. Attach to the available durable task/Ledger record when the owning repo
   requires it.
3. Run the local host probe:

   ```bash
   skills/estate-maintenance/scripts/surface-audit.sh /
   ```

4. Audit repository state without fetching or changing refs:

   ```bash
   skills/estate-maintenance/scripts/repo-sync-audit.sh ~/Projects
   ```

   The helper compares cached remote-tracking refs only. Pass a specific cached
   ref as the second argument (for example, `upstream/main`) when the configured
   branch upstream is not the authority you intend to audit. Treat
   `active=unknown`, unknown ahead/behind counts, and missing refs as blocking
   evidence gaps.

5. Gather matching live evidence only for surfaces the request places in scope.
6. Return an evidence matrix with `surface`, `target`, `observed_at`, `state`,
   `proof`, `gap`, and `next_safe_action`.

## Mutation Gate

Before a write, record:

- exact target and resolved identity;
- source of authority;
- current state and active-work check;
- requested mutation and rollback;
- proof command;
- receipt destination.

Stop at a prepared handoff when authority, identity, credentials, rollback, or
proof is missing. Re-audit the changed surface afterward; do not promote that
result into another surface's truth.

## Finish

Report changed and unchanged surfaces separately. Include commands plus results,
explicitly name unverified live boundaries, and leave one next safe command or
owner decision.
