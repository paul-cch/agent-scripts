---
summary: "Plan to migrate Peter's agent-scripts into Paul's canonical Codex setup"
read_when:
  - Migrating or installing Paul's fork of agent-scripts.
---

# Paul Agent Scripts Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Peter Steinberger's `agent-scripts` setup with a Paul-owned, Codex-only, unified machine profile that preserves the useful operating model while porting identity, tools, and OpenClaw routing to Paul's Mac.

**Architecture:** Fork first, then make Paul-specific source changes in the fork before any global machine wiring. Use a generated machine-state manifest plus reversible backup directory before replacing `~/.codex` surfaces. Keep tool adoption incremental: every Peter-specific tool or skill gets classified, ported, stubbed, or deferred one by one.

**Tech Stack:** Markdown agent instructions, Codex skills, shell/Ruby/TypeScript/Python helper scripts, GitHub CLI, local symlinks, macOS zsh, OpenClaw/homelab SSH routing.

---

## Requirements Captured

- This repo becomes Paul's canonical global agent setup.
- Fork `steipete/agent-scripts` into Paul's GitHub namespace before source changes.
- Use one unified "Paul machine" profile, covering personal Mac, UCL work, and OpenClaw/homelab.
- Expand and adapt `AGENTS.MD`; do not keep Peter's terse rules unchanged.
- Handle Peter-specific tools one by one.
- 1Password is optional, not mandatory.
- Scope is Codex only; do not replace Claude setup.
- Machine-level Codex symlink changes are allowed after the plan is approved.
- Port OpenClaw/Molty/remote-Mac concepts to Paul's real homelab setup.
- Start with a plan, then execute in stages.

## Files And Responsibilities

- Modify: `README.md`
  - Reframe repo identity from Peter's local workspace to Paul's canonical Codex setup.
  - Document fork, install, and migration workflow.
- Modify: `AGENTS.MD`
  - Replace Peter identity/account assumptions with Paul unified profile.
  - Preserve useful workflow semantics: local truth, safety gates, `ship`, releases, PR/CI, zsh safety.
  - Port OpenClaw routing to Paul's homelab reality without hard-coding unverified runtime commands.
- Modify: `tools.md`
  - Convert from "Peter's machines" catalog to "Paul machine tool catalog".
  - Mark each tool as `active`, `optional`, `missing`, or `ported later`.
- Modify: `docs/concurrency.md`
  - Add required front matter so `scripts/docs-list.ts` is clean.
- Create: `docs/migration/paul-adaptation.md`
  - Durable human-readable migration notes, decisions, and one-by-one tool status.
- Create: `docs/migration/machine-state-template.md`
  - Template for the generated backup manifest and preflight report.
- Create: `scripts/audit-machine-setup`
  - Read-only checker for global Codex files, skill symlinks, prompt dirs, expected binaries, broken symlinks, and tool readiness.
- Create: `scripts/install-codex-setup`
  - Reversible installer that backs up existing `~/.codex` surfaces and then wires Codex-only symlinks.
- Create: `scripts/sync-prompts`
  - Copies or symlinks `docs/slash-commands/*.md` into `~/.codex/prompts`.
- Modify: `skills/one-password/SKILL.md`
  - Make 1Password optional and Paul-account neutral; remove Peter/Molty default-token assumptions.
- Modify: `skills/openclaw-relay/SKILL.md`
  - Port defaults from Peter Mac Studio/Molty to Paul's OpenClaw/homelab terminology.
- Modify: `skills/openclaw-relay/scripts/openclaw_relay.py`
  - Stop crashing when default `extensions/acpx` is absent; report a clear missing-dependency diagnostic.
- Modify: `skills/openclaw-relay/config/session_aliases.json`
  - Replace Peter placeholder Discord channel with Paul-local placeholders.
- Modify: selected Peter-specific skill docs one by one
  - `skills/remote-mac/SKILL.md`
  - `skills/mac-maintenance/SKILL.md`
  - `skills/github-project-triage/SKILL.md`
  - `skills/github-author-context/SKILL.md`
  - `skills/speaking/SKILL.md`
  - `skills/domain-dns-ops/SKILL.md`
  - `skills/release-mac-app/SKILL.md`
  - `skills/npm/SKILL.md`
  - `skills/things-todo/SKILL.md`
  - `skills/whatsapp/SKILL.md`
  - `skills/peekaboo/SKILL.md`
- Do not modify: `~/.claude/*`
  - Codex-only migration.

---

### Task 1: Fork And Branch Gate

**Files:**
- No source file edits.

- [ ] **Step 1: Confirm current repo state**

Run:

```bash
git status -sb
git remote -v
git rev-parse HEAD
```

Expected:

```text
## main...origin/main
origin  https://github.com/steipete/agent-scripts.git (fetch)
origin  https://github.com/steipete/agent-scripts.git (push)
```

- [ ] **Step 2: Create Paul fork on GitHub**

Run only after user confirms target namespace:

```bash
gh repo fork steipete/agent-scripts --clone=false --remote=false
```

Expected: GitHub reports the fork URL, normally `https://github.com/<paul-owner>/agent-scripts`.

- [ ] **Step 3: Add fork remote**

Replace `<paul-owner>` with the actual fork owner.

```bash
git remote rename origin upstream
git remote add origin https://github.com/<paul-owner>/agent-scripts.git
git remote -v
```

Expected:

```text
origin   https://github.com/<paul-owner>/agent-scripts.git (fetch)
origin   https://github.com/<paul-owner>/agent-scripts.git (push)
upstream https://github.com/steipete/agent-scripts.git (fetch)
upstream https://github.com/steipete/agent-scripts.git (push)
```

- [ ] **Step 4: Create migration branch**

```bash
git checkout -b codex/paul-agent-scripts-migration
```

Expected: branch changes to `codex/paul-agent-scripts-migration`.

- [ ] **Step 5: Commit policy for this migration**

Use small commits grouped by responsibility:

```text
docs: reframe agent scripts for paul
feat: add codex setup audit
feat: add reversible codex installer
docs: port optional secret workflow
fix: make openclaw relay diagnostics explicit
```

Do not push or open a PR until source validation passes.

---

### Task 2: Add Machine Setup Audit Script

**Files:**
- Create: `scripts/audit-machine-setup`
- Create: `docs/migration/machine-state-template.md`
- Modify: `README.md`

- [ ] **Step 1: Add `scripts/audit-machine-setup`**

Create an executable Ruby script:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
HOME_DIR = Dir.home

def command_path(name)
  ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
    candidate = File.join(dir, name)
    return candidate if File.executable?(candidate) && !File.directory?(candidate)
  end
  nil
end

def path_state(path)
  expanded = File.expand_path(path)
  if File.symlink?(expanded)
    target = File.readlink(expanded)
    { path: expanded, kind: "symlink", target: target, exists: File.exist?(expanded) }
  elsif File.exist?(expanded)
    { path: expanded, kind: File.directory?(expanded) ? "directory" : "file", exists: true }
  else
    { path: expanded, kind: "missing", exists: false }
  end
end

def skill_symlinks
  Dir.glob(File.join(ROOT, "skills", "*")).sort.filter_map do |path|
    next unless File.symlink?(path)

    {
      path: path.sub("#{ROOT}/", ""),
      target: File.readlink(path),
      ok: File.exist?(path)
    }
  end
end

bins = %w[
  bun ruby node npm pnpm gh tmux gws uv yt-dlp ffmpeg mcporter peekaboo
  op rem things tailscale prlctl sign_update notarytool xcrun brew jq python3
]

global_paths = [
  "~/.codex/AGENTS.md",
  "~/.codex/skills",
  "~/.codex/prompts",
  "~/.codex/config.toml"
]

report = {
  repo_root: ROOT,
  generated_at: Time.now.utc.iso8601,
  git_head: `git -C #{ROOT.shellescape} rev-parse HEAD 2>/dev/null`.strip,
  global_paths: global_paths.map { |path| path_state(path) },
  binaries: bins.to_h { |bin| [bin, command_path(bin)] },
  skill_symlinks: skill_symlinks,
  video_transcript_installed: File.directory?(File.join(ROOT, "skills/video-transcript-downloader/node_modules"))
}

puts JSON.pretty_generate(report)
```

- [ ] **Step 2: Fix missing require**

Ruby needs `time` and `shellwords`. Add these near the top:

```ruby
require "shellwords"
require "time"
```

- [ ] **Step 3: Make script executable**

```bash
chmod +x scripts/audit-machine-setup
```

- [ ] **Step 4: Run audit**

```bash
scripts/audit-machine-setup > /tmp/agent-scripts-machine-audit.json
jq '.binaries, .skill_symlinks' /tmp/agent-scripts-machine-audit.json
```

Expected: JSON output listing current Codex surfaces, missing tools, and broken skill symlinks.

- [ ] **Step 5: Add machine-state template**

Create `docs/migration/machine-state-template.md`:

```markdown
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
```

- [ ] **Step 6: Document audit command in README**

Add under `Helpers`:

```markdown
`scripts/audit-machine-setup`
- Prints a read-only JSON report for Codex globals, expected tool binaries, broken skill symlinks, and local package setup.
- Run before replacing global Codex wiring.
```

- [ ] **Step 7: Validate**

```bash
scripts/audit-machine-setup | jq .
scripts/validate-skills
bun scripts/docs-list.ts
```

Expected:

```text
Validated 48 skill(s).
```

`docs-list` should still report `docs/concurrency.md` missing front matter until Task 4.

- [ ] **Step 8: Commit**

```bash
scripts/committer "feat: add codex setup audit" scripts/audit-machine-setup docs/migration/machine-state-template.md README.md
```

---

### Task 3: Reframe Repo Identity For Paul

**Files:**
- Modify: `README.md`
- Create: `docs/migration/paul-adaptation.md`

- [ ] **Step 1: Replace README identity paragraph**

Change:

```markdown
Shared agent instructions, skills, and small portable helpers for Peter's local workspaces.
```

To:

```markdown
Paul's canonical Codex agent setup: shared instructions, reusable skills, slash-command prompts, and portable helpers for local Mac, UCL, and OpenClaw/homelab work.
```

- [ ] **Step 2: Change global discovery docs to Codex-only**

Replace the global discovery block with:

```markdown
Global Codex discovery points here:
- `~/.codex/skills -> ~/Projects/agent-scripts/skills`

Claude is intentionally out of scope for this migration. Do not replace `~/.claude/skills` from this repo.
```

- [ ] **Step 3: Change global instructions docs to Codex-only**

Replace the global setup block with:

```markdown
Global Codex setup:
- `~/.codex/AGENTS.md -> ~/Projects/agent-scripts/AGENTS.MD`

Existing Claude setup is left alone unless Paul explicitly asks for a separate Claude migration.
```

- [ ] **Step 4: Add fork/upstream note**

Add near the syncing section:

```markdown
This repo is Paul-owned after migration. Keep `upstream` pointed at `steipete/agent-scripts` for reference, and keep `origin` pointed at Paul's fork.
```

- [ ] **Step 5: Create adaptation note**

Create `docs/migration/paul-adaptation.md`:

```markdown
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

## Tool Porting Policy

Handle tools one by one:
- `active`: installed and verified on Paul's machine
- `optional`: useful but not required
- `missing`: referenced but not installed
- `ported later`: Peter-specific workflow preserved as notes until Paul equivalent exists
- `delete candidate`: not useful for Paul after review

## Secret Policy

1Password is optional, not mandatory. Skills may recommend `op` when configured, but must not assume `op`, a service account token, or Peter's vault names.

## OpenClaw Policy

Port concepts, not Peter's topology. Do not use Peter hostnames, Peter accounts, Molty assumptions, or `/Users/steipete` paths as defaults.
```

- [ ] **Step 6: Validate docs**

```bash
bun scripts/docs-list.ts
```

Expected: new migration docs appear with summaries.

- [ ] **Step 7: Commit**

```bash
scripts/committer "docs: reframe agent scripts for paul" README.md docs/migration/paul-adaptation.md
```

---

### Task 4: Expand And Port `AGENTS.MD`

**Files:**
- Modify: `AGENTS.MD`
- Modify: `docs/concurrency.md`

- [ ] **Step 1: Replace work style line**

Change:

```markdown
Work style: telegraph; noun-phrases ok; drop grammar; min tokens.
```

To:

```markdown
Work style: friendly, concise, evidence-first, high-agency. Keep status updates compact; use plain engineering prose in final replies.
```

- [ ] **Step 2: Replace workspace and identity rules**

Replace the first Core bullets with:

```markdown
- Workspace: `~/Projects` for source repos; `~/Projects/oss` for third-party/OSS unless repo instructions say otherwise.
- This fork is Paul's canonical Codex setup. `upstream` may point to `steipete/agent-scripts`; do not clone or push Peter-owned repos unless explicitly asked.
- `../agent-skills` = `https://github.com/openclaw/agent-skills`; public shared skills, not personal machine truth.
- "Make a note" here => terse `AGENTS.MD` or migration-doc edit unless the user names a different notes surface.
```

- [ ] **Step 3: Port routing identity**

Replace Peter-specific routing bullets with:

```markdown
- Secrets/API keys/live creds: use explicit known secret routes only; env only if already exported; never enumerate broad env/secrets.
- 1Password is optional. If `op` is configured, use `$one-password`; otherwise ask for the narrow secret route.
- New API keys: store in the configured secret manager when one exists; otherwise keep temp/env use scoped to the current task and ask before persistence.
- Google-facing assistant work: prefer local `gws` when the task is Google-facing and the account is already configured.
- OpenClaw/homelab: keep source, host/runtime, and live assistant surfaces distinct. Use Paul's Homelab/OpenClaw docs and live verification before host mutation.
```

- [ ] **Step 4: Keep useful safety sections**

Preserve these sections with minimal edits:

```markdown
## Project Defaults
## PR / CI
## Runtime Safety
## Git
```

Remove direct Peter references such as:

```text
call Peter aloud
gog+clawdbot@gmail.com
service@openclaw.org
steipete repo
```

- [ ] **Step 5: Add Codex-only global wiring rule**

Add under Core:

```markdown
- Codex-only setup: this repo may own `~/.codex/AGENTS.md`, `~/.codex/skills`, and `~/.codex/prompts`. Do not alter `~/.claude/*` from this workflow.
```

- [ ] **Step 6: Add front matter to `docs/concurrency.md`**

Insert at the top:

```markdown
---
summary: "Swift concurrency notes for practical isolation, tasks, and Sendable review"
read_when:
  - Reviewing or fixing Swift concurrency behavior.
---

```

- [ ] **Step 7: Validate docs and skills**

```bash
scripts/validate-skills
bun scripts/docs-list.ts
```

Expected:

```text
Validated 48 skill(s).
```

`docs-list` should no longer report `docs/concurrency.md` missing front matter.

- [ ] **Step 8: Commit**

```bash
scripts/committer "docs: expand paul global agent rules" AGENTS.MD docs/concurrency.md
```

---

### Task 5: Add Reversible Codex Installer

**Files:**
- Create: `scripts/install-codex-setup`
- Create: `scripts/sync-prompts`
- Modify: `README.md`

- [ ] **Step 1: Add `scripts/install-codex-setup`**

Create an executable Ruby script:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "time"

ROOT = File.expand_path("..", __dir__)
HOME_DIR = Dir.home
CODEX_DIR = File.join(HOME_DIR, ".codex")
BACKUP_ROOT = File.join(CODEX_DIR, "backups", "agent-scripts")
STAMP = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
BACKUP_DIR = File.join(BACKUP_ROOT, STAMP)

TARGETS = {
  File.join(CODEX_DIR, "AGENTS.md") => File.join(ROOT, "AGENTS.MD"),
  File.join(CODEX_DIR, "skills", "agent-scripts") => File.join(ROOT, "skills")
}.freeze

def backup_path(path)
  File.join(BACKUP_DIR, path.sub(%r{\A/}, ""))
end

def backup_existing(path)
  return unless File.exist?(path) || File.symlink?(path)

  dest = backup_path(path)
  FileUtils.mkdir_p(File.dirname(dest))
  if File.symlink?(path)
    File.symlink(File.readlink(path), dest)
  elsif File.directory?(path)
    FileUtils.cp_r(path, dest, preserve: true)
  else
    FileUtils.cp(path, dest, preserve: true)
  end
end

def replace_with_symlink(path, target)
  parent = File.dirname(path)
  FileUtils.mkdir_p(parent)
  FileUtils.rm_f(path) if File.symlink?(path) || File.file?(path)
  if File.directory?(path)
    raise "#{path} is a directory; move it from backup manually before replacing"
  end
  File.symlink(target, path)
end

unless ARGV.include?("--apply")
  warn "Dry run. Re-run with --apply to install Codex symlinks."
  TARGETS.each do |path, target|
    puts "would link #{path} -> #{target}"
  end
  exit 0
end

FileUtils.mkdir_p(BACKUP_DIR)
TARGETS.each_key { |path| backup_existing(path) }
TARGETS.each { |path, target| replace_with_symlink(path, target) }

puts "backup: #{BACKUP_DIR}"
TARGETS.each { |path, target| puts "linked #{path} -> #{target}" }
```

- [ ] **Step 2: Make installer executable**

```bash
chmod +x scripts/install-codex-setup
```

- [ ] **Step 3: Add `scripts/sync-prompts`**

Create an executable Ruby script:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"

ROOT = File.expand_path("..", __dir__)
PROMPT_SRC = File.join(ROOT, "docs", "slash-commands")
PROMPT_DEST = File.join(Dir.home, ".codex", "prompts")

unless ARGV.include?("--apply")
  warn "Dry run. Re-run with --apply to copy prompts."
  Dir.glob(File.join(PROMPT_SRC, "*.md")).sort.each do |path|
    next if File.basename(path) == "README.md"

    puts "would copy #{path} -> #{File.join(PROMPT_DEST, File.basename(path))}"
  end
  exit 0
end

FileUtils.mkdir_p(PROMPT_DEST)
Dir.glob(File.join(PROMPT_SRC, "*.md")).sort.each do |path|
  next if File.basename(path) == "README.md"

  FileUtils.cp(path, File.join(PROMPT_DEST, File.basename(path)))
end

puts "synced prompts to #{PROMPT_DEST}"
```

- [ ] **Step 4: Make prompt sync executable**

```bash
chmod +x scripts/sync-prompts
```

- [ ] **Step 5: Dry-run installer**

```bash
scripts/install-codex-setup
scripts/sync-prompts
```

Expected: both scripts print only `would ...` lines and do not change `~/.codex`.

- [ ] **Step 6: Document install flow**

Add to `README.md`:

```markdown
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

The installer backs up replaced Codex files under `~/.codex/backups/agent-scripts/<timestamp>/`.
```

- [ ] **Step 7: Validate**

```bash
ruby -c scripts/install-codex-setup
ruby -c scripts/sync-prompts
scripts/validate-skills
```

Expected:

```text
Syntax OK
Syntax OK
Validated 48 skill(s).
```

- [ ] **Step 8: Commit**

```bash
scripts/committer "feat: add reversible codex installer" scripts/install-codex-setup scripts/sync-prompts README.md
```

---

### Task 6: Make 1Password Optional

**Files:**
- Modify: `skills/one-password/SKILL.md`
- Modify: `skills/npm/SKILL.md`
- Modify: `docs/npm-publish-with-1password.md`

- [ ] **Step 1: Replace mandatory wording in `skills/one-password/SKILL.md`**

Change:

```markdown
Follow the official CLI get-started steps. Don't guess install commands.
```

To:

```markdown
Use only when 1Password is already configured or the user explicitly asks to configure it. 1Password is optional in Paul's setup.
```

- [ ] **Step 2: Remove Peter service-account default**

Replace the service account bullets with:

```markdown
- Prefer service-account tokens before interactive 1Password only when a scoped token is already configured for the exact workflow.
- Do not assume `OP_SERVICE_ACCOUNT_TOKEN`, vault names, item names, or account names.
- If no configured token exists, ask for the narrow secret route before using desktop-app sign-in.
- Export/pass tokens only for the single command that needs them.
- Print presence/shape only, never token or secret values.
```

- [ ] **Step 3: Make default account neutral**

Replace:

```markdown
- Default account for personal/work secrets is `my.1password.com`.
```

With:

```markdown
- No default 1Password account is assumed. If multiple accounts exist, ask which account or use the account named by the user.
```

- [ ] **Step 4: Update npm skill**

In `skills/npm/SKILL.md`, replace Peter-specific item text with:

```markdown
- 1Password is optional. If npm credentials or OTP are configured in `op`, use `$one-password`; otherwise use the current npm login or ask for the narrow auth route.
- Do not assume a specific npm 1Password item title, vault, username, or account.
```

- [ ] **Step 5: Update npm doc title**

Change `docs/npm-publish-with-1password.md` title to:

```markdown
# Optional npm publish via tmux + op
```

Add under the title:

```markdown
Paul setup note: this path is optional. Use it only when 1Password CLI is installed and configured for the relevant npm account.
```

- [ ] **Step 6: Validate**

```bash
scripts/validate-skills
bun scripts/docs-list.ts
```

Expected: validation passes.

- [ ] **Step 7: Commit**

```bash
scripts/committer "docs: make 1password optional" skills/one-password/SKILL.md skills/npm/SKILL.md docs/npm-publish-with-1password.md
```

---

### Task 7: Port OpenClaw Relay To Paul

**Files:**
- Modify: `skills/openclaw-relay/SKILL.md`
- Modify: `skills/openclaw-relay/scripts/openclaw_relay.py`
- Modify: `skills/openclaw-relay/config/session_aliases.json`
- Modify: `skills/remote-mac/SKILL.md`

- [ ] **Step 1: Update relay prose**

Replace Peter-specific paragraph:

```markdown
For Peter's setup, Molty normally lives on the Mac Studio gateway, reached as `steipete@steipete-macstudio.local`; avoid the `mac-studio` SSH alias for one-shot relay work because that alias auto-attaches tmux.
```

With:

```markdown
For Paul's setup, resolve the current OpenClaw runtime from Homelab/OpenClaw docs and live checks before using SSH. Do not assume Peter's Mac Studio, Molty, or `steipete` hostnames.
```

- [ ] **Step 2: Update relay defaults**

Replace default host line with:

```markdown
- ssh host: set `OPENCLAW_RELAY_HOST` or pass `--host`; no default remote host is assumed for Paul's setup
```

- [ ] **Step 3: Patch missing acpx diagnostic**

In `skills/openclaw-relay/scripts/openclaw_relay.py`, find the function that runs local subprocesses. Add a preflight before `subprocess.run`:

```python
    if cwd and not Path(cwd).exists():
        return subprocess.CompletedProcess(
            argv,
            127,
            "",
            f"missing working directory: {cwd}\n"
        )
```

If the existing function uses `check=True`, ensure callers receive a clear error rather than a Python traceback.

- [ ] **Step 4: Add doctor-specific message**

In the doctor command, when `acpx` cwd is missing, print:

```text
OpenClaw relay is not configured: missing acpx repo. Set OPENCLAW_RELAY_ACPX_REPO or pass --acpx-repo.
```

- [ ] **Step 5: Replace session aliases**

Change `skills/openclaw-relay/config/session_aliases.json` to:

```json
{
  "main": "agent:<paul-agent-id>:main",
  "homelab": "agent:<paul-agent-id>:homelab",
  "maintainers": "agent:<paul-agent-id>:maintainers"
}
```

- [ ] **Step 6: Rewrite `skills/remote-mac/SKILL.md` as Paul topology stub**

Replace the Peter topology section with:

```markdown
## Paul's Topology

Use only after checking the current Homelab/OpenClaw docs and live host state.

Known routing principles:
- Keep local source repos, homelab host/runtime, and live assistant surfaces distinct.
- Prefer configured SSH aliases or repo docs over remembered hostnames.
- Verify host identity before running commands.
- Do not install, restart, unload, or mutate services without explicit approval.

Expected source areas:
- `~/Projects/Homelab/homelab-clean`
- OpenClaw source/runtime docs inside that repo
```

- [ ] **Step 7: Run relay doctor**

```bash
python3 skills/openclaw-relay/scripts/openclaw_relay.py doctor
```

Expected: no Python traceback. If acpx is missing, output should be a clear configuration diagnostic.

- [ ] **Step 8: Validate**

```bash
python3 -m py_compile skills/openclaw-relay/scripts/openclaw_relay.py
scripts/validate-skills
```

Expected: no syntax errors and skill validation passes.

- [ ] **Step 9: Commit**

```bash
scripts/committer "fix: port openclaw relay diagnostics" skills/openclaw-relay/SKILL.md skills/openclaw-relay/scripts/openclaw_relay.py skills/openclaw-relay/config/session_aliases.json skills/remote-mac/SKILL.md
```

---

### Task 8: Classify Peter-Specific Tools One By One

**Files:**
- Modify: `tools.md`
- Modify: `docs/migration/paul-adaptation.md`

- [ ] **Step 1: Create status table in `tools.md`**

Replace the opening sentence with:

```markdown
CLI tools available or planned on Paul's machine. Treat status as live-checkable, not permanent truth.
```

Add table:

```markdown
| Tool | Status | Paul route |
| --- | --- | --- |
| `gh` | active | GitHub CLI on PATH |
| `gws` | active | Google-facing assistant work |
| `peekaboo` | active | macOS screenshot/UI inspection when permissions allow |
| `mcporter` | active | Browser/MCP fallback |
| `yt-dlp`/`ffmpeg` | active | Video transcript/download helper |
| `op` | optional | Not mandatory; configure only when needed |
| `rem` | missing | Apple Reminders CLI candidate |
| `things` | missing | Things 3 CLI candidate |
| `tailscale` | missing | Homelab remote routing candidate |
| `prlctl` | missing | Parallels VM workflow candidate |
| `bird` | ported later | X/Twitter workflow not configured |
| `sonoscli` | ported later | Local speaker workflow not configured |
| `clawdis` | ported later | Messaging gateway not configured |
| `oracle` | active candidate | Local checkout exists under `~/Projects/skills/oracle`; verify before use |
```

- [ ] **Step 2: Keep command sections only when useful**

For each Peter-specific section, add a one-line status before commands:

```markdown
Status on Paul's machine: `ported later`; do not run until configured.
```

- [ ] **Step 3: Record tool decisions in adaptation doc**

Add:

```markdown
## Tool Decisions

- `gh`: active.
- `gws`: active.
- `peekaboo`: active binary present; permissions must be checked live.
- `mcporter`: active binary present.
- `video-transcript-downloader`: candidate; requires `npm ci`.
- `op`: optional.
- `rem`/`things`: missing; decide later.
- Peter social/media tools: port later one by one.
```

- [ ] **Step 4: Validate docs**

```bash
bun scripts/docs-list.ts
```

Expected: docs list succeeds.

- [ ] **Step 5: Commit**

```bash
scripts/committer "docs: classify paul tool catalog" tools.md docs/migration/paul-adaptation.md
```

---

### Task 9: Resolve Broken Skill Symlinks Deliberately

**Files:**
- Modify: `docs/migration/paul-adaptation.md`
- Potentially modify tracked symlinks under `skills/`

- [ ] **Step 1: List broken symlinks**

```bash
for l in skills/*; do
  if [ -L "$l" ]; then
    if [ -e "$l" ]; then
      printf 'ok      %s -> %s\n' "$l" "$(readlink "$l")"
    else
      printf 'BROKEN  %s -> %s\n' "$l" "$(readlink "$l")"
    fi
  fi
done
```

Expected broken list before migration:

```text
skills/autoreview
skills/birdclaw
skills/discrawl
skills/gog
skills/handoff
skills/imsg
skills/slacrawl
skills/wacli
skills/wacrawl
```

- [ ] **Step 2: Clone public shared skills first**

Only for public OpenClaw shared skills:

```bash
git clone https://github.com/openclaw/agent-skills.git ../agent-skills
```

Expected: `skills/autoreview` and `skills/handoff` stop being broken if those paths exist in `../agent-skills`.

- [ ] **Step 3: Re-run symlink check**

```bash
for l in skills/*; do
  if [ -L "$l" ] && [ ! -e "$l" ]; then
    printf 'BROKEN  %s -> %s\n' "$l" "$(readlink "$l")"
  fi
done
```

Expected: only repo-owned skills remain broken.

- [ ] **Step 4: Decide each repo-owned symlink one by one**

For each remaining symlink, choose exactly one action:

```text
clone repo
replace with Paul-local skill
remove symlink
leave broken but documented
```

Decision list:

```text
birdclaw:
discrawl:
gog:
imsg:
slacrawl:
wacli:
wacrawl:
```

- [ ] **Step 5: Record decisions**

Add to `docs/migration/paul-adaptation.md`:

```markdown
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
```

- [ ] **Step 6: Validate after each symlink action**

```bash
scripts/validate-skills
```

Expected: validation still passes.

- [ ] **Step 7: Commit decisions and symlink changes**

Use exact paths changed:

```bash
scripts/committer "docs: record skill symlink migration decisions" docs/migration/paul-adaptation.md
```

If symlink files are changed, include them explicitly.

---

### Task 10: Install Video Transcript Downloader

**Files:**
- No source edits unless package lock changes unexpectedly.

- [ ] **Step 1: Install dependencies**

```bash
npm ci --prefix skills/video-transcript-downloader
```

Expected: `node_modules` created under `skills/video-transcript-downloader`.

- [ ] **Step 2: Smoke help command**

```bash
skills/video-transcript-downloader/scripts/vtd.js transcript --help
```

Expected: help output prints without `ERR_MODULE_NOT_FOUND`.

- [ ] **Step 3: Check git status**

```bash
git status -sb
```

Expected: no source changes except maybe package-lock if npm updated it. If package-lock changed, inspect before committing.

- [ ] **Step 4: Commit only if source changed**

If `package-lock.json` changed:

```bash
scripts/committer "chore: refresh video transcript lockfile" skills/video-transcript-downloader/package-lock.json
```

If no source changed, record in final migration receipt instead of committing.

---

### Task 11: Apply Codex Global Wiring

**Files:**
- Machine-level changes under `~/.codex`
- No `~/.claude` changes

- [ ] **Step 1: Preflight audit**

```bash
scripts/audit-machine-setup > /tmp/agent-scripts-before.json
jq '.global_paths' /tmp/agent-scripts-before.json
```

Expected: current `~/.codex/AGENTS.md`, `~/.codex/skills`, and prompts state visible.

- [ ] **Step 2: Dry run installer**

```bash
scripts/install-codex-setup
scripts/sync-prompts
```

Expected: only `would ...` output.

- [ ] **Step 3: Apply installer**

```bash
scripts/install-codex-setup --apply
scripts/sync-prompts --apply
```

Expected:

```text
backup: /Users/paulcouach/.codex/backups/agent-scripts/<timestamp>
linked /Users/paulcouach/.codex/AGENTS.md -> /Users/paulcouach/Projects/agent-scripts/AGENTS.MD
linked /Users/paulcouach/.codex/skills/agent-scripts -> /Users/paulcouach/Projects/agent-scripts/skills
synced prompts to /Users/paulcouach/.codex/prompts
```

- [ ] **Step 4: Postflight audit**

```bash
scripts/audit-machine-setup > /tmp/agent-scripts-after.json
jq '.global_paths' /tmp/agent-scripts-after.json
```

Expected: Codex globals point at this repo or include copied prompts.

- [ ] **Step 5: Verify no Claude mutation**

```bash
ls -ld ~/.claude ~/.claude/skills 2>/dev/null || true
```

Expected: no changes made by installer.

- [ ] **Step 6: Record receipt**

Add backup path and audit summary to `docs/migration/paul-adaptation.md`.

- [ ] **Step 7: Commit receipt**

```bash
scripts/committer "docs: record codex install receipt" docs/migration/paul-adaptation.md
```

---

### Task 12: Full Validation And Push

**Files:**
- All changed source files.

- [ ] **Step 1: Run source validations**

```bash
scripts/validate-skills
bun scripts/docs-list.ts
ruby -c scripts/audit-machine-setup
ruby -c scripts/install-codex-setup
ruby -c scripts/sync-prompts
python3 -m py_compile skills/openclaw-relay/scripts/openclaw_relay.py
```

Expected:

```text
Validated 48 skill(s).
Syntax OK
Syntax OK
Syntax OK
```

- [ ] **Step 2: Run package smoke**

```bash
npm ci --prefix skills/video-transcript-downloader
skills/video-transcript-downloader/scripts/vtd.js transcript --help
```

Expected: help output without module errors.

- [ ] **Step 3: Run machine audit**

```bash
scripts/audit-machine-setup | jq '.binaries, .skill_symlinks'
```

Expected: machine state visible, no script errors.

- [ ] **Step 4: Inspect diff**

```bash
git diff --stat
git diff -- README.md AGENTS.MD tools.md docs/migration/paul-adaptation.md
```

Expected: Peter-specific identity is replaced by Paul-specific, Codex-only language.

- [ ] **Step 5: Push branch**

```bash
git push -u origin codex/paul-agent-scripts-migration
```

- [ ] **Step 6: Open PR in Paul's fork**

```bash
gh pr create --fill
```

Expected: PR targets Paul's fork default branch, not `steipete/agent-scripts`.

---

## Self-Review

Spec coverage:
- Canonical global setup: Tasks 3, 4, 5, 11.
- Fork first: Task 1.
- Unified profile: Tasks 3 and 4.
- Expanded AGENTS: Task 4.
- Tools one by one: Tasks 8 and 9.
- 1Password optional: Task 6.
- Codex only: Tasks 3, 5, 11.
- Machine symlink changes allowed but gated: Tasks 5 and 11.
- OpenClaw port: Task 7.
- Plan first: this document.

Placeholder scan:
- No task uses "TBD" or asks for unspecified code.
- Symlink decisions deliberately include explicit action choices because the user asked to go one by one.

Risk gates:
- Do not run Task 11 until source migration is reviewed.
- Do not change `~/.claude`.
- Do not install or configure 1Password unless Paul asks separately.
- Do not assume Peter hostnames, accounts, vaults, or social tools are valid on Paul's machine.
