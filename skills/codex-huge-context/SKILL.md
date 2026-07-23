---
name: codex-huge-context
description: "Codex large-context audits: provider budget, compaction headroom, catalogue consistency, and auth preflight."
---

# Codex Huge Context

Audit large-context Codex configuration. Do not enable a provider, change
`~/.codex`, store a credential, restart a shared app server, or incur direct API
cost merely because this skill loads.

## Budget

Derive safe input from current provider facts:

```text
safe input = provider total context - provider maximum output
```

Leave additional headroom between automatic compaction and safe input for the
next prompt, tool schemas/results, instructions, serialization, and compaction.
Do not treat model limits, entitlement, price, or catalogue values in an old
receipt as current.

## Read-Only Preflight

Use the bundled parser, which relies on Python's TOML implementation and rejects
duplicate keys:

```bash
python3 skills/codex-huge-context/scripts/preflight.py \
  --config ~/.codex/config.toml \
  --total-context TOTAL \
  --max-output MAX_OUTPUT \
  --min-headroom 50000
```

The check validates the selected provider, positive context and compaction
values, `total` compaction scope, safe-input arithmetic, model-catalogue
consistency, and auth-helper shape. It does not execute the helper by default.

Use `--run-auth-helper` only when the user explicitly requests credential
delivery proof through the configured secret route. The helper output is never
printed.

## Change Gate

Before any change:

- verify the provider and model are actually supported;
- identify the configured secret manager or narrow credential route;
- back up only the files being changed;
- preserve plugin, MCP, connector, notification, approval, and unrelated model
  settings;
- define rollback and a maximum-cost live probe.

Keep inference authentication separate from ChatGPT/connector OAuth when the
provider supports that topology. Do not copy OAuth state between hosts.

## Runtime Proof

Configuration on disk does not prove a running shared app server loaded it.
After an approved change, let active turns finish, restart only the named app
or server, start a fresh session, and verify:

- reported provider and model;
- effective context and compaction threshold;
- secret-safe inference probe;
- connector login independently when connectors matter.

Resume an old session only when preserving its recorded provider is intentional.
Report server-side clamps or entitlement errors as provider truth, not a client
configuration success.
