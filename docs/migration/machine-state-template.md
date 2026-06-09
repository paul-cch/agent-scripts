---
summary: "Machine-state migration receipt template for Paul agent-scripts adoption"
read_when:
  - Auditing or installing Paul's Codex setup.
---

# Machine State Template

Use `scripts/audit-machine-setup` before and after installing global Codex wiring.

## Preflight

- Date:
- Repo branch:
- Repo commit:
- Existing `~/.codex/AGENTS.md`:
- Existing `~/.codex/skills`:
- Existing `~/.codex/prompts`:
- Broken repo skill symlinks:
- Missing high-priority binaries:

## Backup

- Backup directory:
- Files copied:
- Symlinks copied:

## Install Result

- `~/.codex/AGENTS.md`:
- `~/.codex/skills`:
- `~/.codex/prompts`:
- Validation command:
- Validation result:

## Rollback

Restore files from the backup directory recorded above.

