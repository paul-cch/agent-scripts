# Agent Scripts

Paul's canonical Codex agent setup: shared instructions, reusable skills, slash-command prompts, and portable helpers for local Mac, UCL, and OpenClaw/homelab work.

This repo is the canonical place for:
- `AGENTS.MD`: shared hard rules for Codex/Claude-style agents
- `skills/`: reusable workflow skills, including repo-owned skills exposed by symlink
- `scripts/`: dependency-light helpers used across projects
- `hooks/`: local guardrails such as skill validation

## Skills

Skills are the main routing layer. Each `skills/<name>/SKILL.md` has YAML front matter:

```yaml
---
name: skill-name
description: "Short generic trigger phrase."
---
```

Rules:
- Keep descriptions short and generic; optimize for routing, not documentation.
- Keep skill bodies terse and operational.
- Prefer helper scripts under `skills/<name>/scripts/` when a workflow has repeatable commands.
- Validate after edits: `scripts/validate-skills`.
- Quote `description` in front matter.

Global Codex discovery points here:
- `~/.codex/skills -> ~/Projects/agent-scripts/skills`
- Use `~/.claude/` only when explicitly requested; this migration is Codex-only.

Shared personal skills live as real folders in `skills/`. Public OpenClaw shared skills live in `../agent-skills` and are exposed here with tracked relative symlinks. Repo-owned skills stay canonical in their repo and are exposed here the same way, for example:

```text
skills/autoreview -> ../../agent-skills/skills/autoreview
skills/discrawl -> ../../discrawl/.agents/skills/discrawl
```

Current symlinked repo-owned skills include `birdclaw`, `discrawl`, `gog`, `imsg`, `slacrawl`, `wacli`, and `wacrawl`.

Paul-specific operational skills include:
- `estate-maintenance`: read-only-first Homelab/Mac inventory with separate proof surfaces and approved mutation gates.
- `xcode-sync`: exact Xcode build provenance, compatibility, rollback, selection, and first-launch proof.
- `codex-huge-context`: read-only provider/context/compaction/catalogue preflight; it never enables a provider by loading.

## Agent Instructions

Shared hard rules live in `AGENTS.MD`.

Global setup:
- `~/.codex/AGENTS.md -> ~/Projects/agent-scripts/AGENTS.MD`
- `~/.codex/skills -> ~/Projects/agent-scripts/skills`
- `~/.codex/prompts` mirrors `docs/slash-commands/`

This repo is Paul-owned after migration. Keep `upstream` pointed at `steipete/agent-scripts` for reference, and keep `origin` pointed at Paul's fork.

Downstream repos should use a pointer-style `AGENTS.MD`:

```text
READ ~/Projects/agent-scripts/AGENTS.MD BEFORE ANYTHING (skip if missing).
```

Repo-specific rules go below that pointer. Do not copy the shared blocks into downstream repos.

## Helpers

`scripts/committer`
- Stages exactly the listed files.
- Enforces a non-empty commit message.
- Runs skill validation before committing.

`scripts/validate-skills`
- Checks every `skills/*/SKILL.md`.
- Verifies UTF-8 YAML front matter plus required `name` and `description`.
- Enable as a local hook with `git config core.hooksPath hooks`.

`scripts/docs-list.ts`
- Walks `docs/`.
- Enforces `summary` and `read_when` front matter.
- Prints onboarding summaries for repos that wire it in.

`scripts/browser-tools.ts`
- Standalone Chrome DevTools helper.
- Common commands: `start --profile`, `nav <url>`, `eval '<js>'`, `screenshot`, `console`, `network`, `search --content "<query>"`, `content <url>`, `inspect`, `kill --all --force`.
- Build optional binary with `bun build scripts/browser-tools.ts --compile --target bun --outfile bin/browser-tools`.

`scripts/audit-machine-setup`
- Prints a read-only JSON report for Codex globals, expected tool binaries, broken skill symlinks, and local package setup.
- Run before replacing global Codex wiring.

`scripts/install-codex-setup`
- Reversible Codex-only installer. Dry runs with `scripts/install-codex-setup`, apply with `--apply`.
- Backs up replaced `~/.codex` surfaces under `~/.codex/backups/agent-scripts/<timestamp>/`.
- Links `~/.codex/skills` directly to this repo's `skills/`; this replaces the existing skills directory after backup.

`scripts/sync-prompts`
- Copies `docs/slash-commands/*.md` into `~/.codex/prompts` (excluding `README.md`).
- On apply, backs up any changed destination prompt before replacing it.

## Paul Codex Install

Preflight:

```bash
scripts/audit-machine-setup > /tmp/agent-scripts-before.json
scripts/install-codex-setup
scripts/sync-prompts
```

Apply after reviewing the dry run:

```bash
scripts/install-codex-setup --apply
scripts/sync-prompts --apply
scripts/audit-machine-setup > /tmp/agent-scripts-after.json
```

## Syncing

Treat this repo as canonical for shared agent rules and portable helper scripts.

When syncing downstream repos:
- Pull latest here first.
- Ensure each target repo starts with the pointer-style `AGENTS.MD`.
- Preserve repo-local rules below the pointer.
- Copy helper changes both directions only when the helper is meant to stay byte-identical.
- Keep scripts dependency-free and portable; no repo-specific imports or path aliases.

For submodules, repeat the pointer check inside each subrepo, push those changes, then bump submodule SHAs in the parent repo.
