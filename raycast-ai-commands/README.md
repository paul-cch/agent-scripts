# Raycast AI Commands — Hermes Personality Port

These prompts mirror the Codex/Hermes behavioral stack for Raycast's "Create AI Command" form.

## What's here

| File | Raycast AI Command name | Codex source |
|---|---|---|
| `01-hermes.md` | Hermes | `SOUL.md` + `USER.md` + Hermes `SOUL.md`/`USER.md` |
| `02-handoff.md` | Handoff | `~/.codex/prompts/handoff.md` |
| `03-pickup.md` | Pickup | `~/.codex/prompts/pickup.md` |
| `04-landpr.md` | Land PR | `~/.codex/prompts/landpr.md` |
| `05-fixissue.md` | Fix Issue | `~/.codex/prompts/fixissue.md` |
| `06-triage-brief.md` | Triage Brief | Hermes default output shape |
| `scripts/recall-context.sh` | Script Command: Recall Context | `session_start_context.py` |
| `scripts/log-status.sh` | Script Command: Log Status | `stop_status_log.py` |

## How to install

1. Open Raycast → search "Create AI Command"
2. For each `.md` file: copy the **Prompt** section into the prompt field
3. Set **Name**, **Model**, **Creativity**, **Reasoning Effort** per the file's header
4. Save with `⌘↵`
5. For the scripts: save as `.sh` files in your Raycast Script Commands directory, then Raycast → "Create Script Command"

## What doesn't transfer

- **Autonomous hooks** — Raycast has no session lifecycle. Run "Recall Context" manually before Hermes.
- **Sandbox execution** — Raycast AI is advisory. Use Script Commands for the action layer.
- **MCP servers** — replaced by Script Commands that curl the endpoints.
- **Skills system** — referenced in prompts as "read ~/.codex/skills/X/SKILL.md" but not auto-loaded.
- **Memory Core auto-recall** — manual two-step: run "Recall Context" → paste into AI Chat.
