# Chief Of Staff Lane Map

Read this when a run needs lane-specific authority, route choice, or priority
between lanes. Use the narrowest relevant reads; do not drag every run through
every system.

## Routes

- `gws`: Google-facing calendar, Gmail, Drive, Docs, Sheets, and related reads.
  Calendar briefs use `gws calendar +agenda --days 2 --timezone Europe/London
  --format json`. Gmail reads should be bounded and metadata-first unless the
  user asks for message content.
- `ntn`: Notion live API. For mirrors, prefer targeted
  `ntn datasources query <data-source-id> --filter ... --json` checks with
  stable row IDs or `External ID` filters. Do not burn time retrying gated or
  flaky Notion SQL/AI/query surfaces.
- `gh`: GitHub issues, PRs, CI, releases, and maintainer queues.
- Local repos/workspaces: first-class truth for Homelab, Placement,
  Dissertation, PLAN, course artifacts, and private drafts.
- `obsidian`: local note route when history, backlinks, or written plans matter.

Do not assume `notcrawl`, `things`, `rem`, or `gitcrawl` are installed. If the
user asks for those backends, check availability and report the missing route or
use an approved fallback.

## Lane Authorities

- `Calendar/Gmail`: use `gws`. Calendar commitments beat aspirational task
  timing. Email/message history is read only when communications context is in
  scope.
- `Daily planning`: prefer the Operator Cockpit contract if
  `~/.codex/operator-cockpit.md` exists. If absent, record
  `NO_OPERATOR_COCKPIT` in the receipt and continue from live surfaces.
- `Notion`: often a mirror, proposal surface, or bounded live check, not a
  blanket primary source. In Placement and Dissertation mirror workflows,
  GitHub/local repo truth flows into Notion; use no-op receipts when the mirror
  already matches.
- `Placement`: canonical workspace is
  `/Users/paulcouach/Documents/1 - Projects 🛠️/UCL 🏛️/Placement`. Use live
  GitHub/local repo evidence before Notion mirror rows. For ignored source
  files, use the canonical checkout rather than detached worktrees that may lack
  ignored mirrors.
- `Dissertation`: canonical workspace is
  `/Users/paulcouach/Documents/1 - Projects 🛠️/UCL 🏛️/Dissertation`. Keep
  knowledge-base updates separate from task-mirror updates. Use targeted
  `External ID` checks for issue mirrors.
- `PLAN / applications / daily work`: canonical workspace is
  `/Users/paulcouach/Documents/1 - Projects 🛠️/UCL 🏛️/PLAN`. For
  job/application scans, read the advert and local materials before drafting.
- `Coursework/exams`: start from local UCL folders and Moodle mirrors for study
  work. Treat deadlines/admin facts as unverified unless checked through an
  authenticated live route or a trusted current local receipt.
- `Homelab/OpenClaw`: start from
  `/Users/paulcouach/Projects/Homelab/homelab-clean`, GitHub/Paperclip-derived
  queue state when relevant, and repo scripts/docs. Keep source checkout,
  host/runtime state, and live assistant surfaces distinct. Use runtime access
  only when required and through the configured narrow route.
- `UCL bridge checks`: when a Homelab bridge lane is explicitly in scope, prefer
  the repo scripts `scripts/check-placement-bridge.py`,
  `scripts/check-dissertation-bridge.py`, `scripts/check-plan-bridge.py`, or
  `scripts/check-ucl-task-bridge.py` in the Homelab checkout.
- `Public web`: use only for current public facts that cannot be verified
  locally, or when the task is an advert/news/current-facts workflow.

If sources conflict, surface the conflict and name the authority for that lane.
If a source is unavailable, continue from remaining evidence and label the gap.
Never scrape Moodle with a browser, persist credentials, or expose course
content publicly unless explicitly approved.

## Work Lanes

- `Homelab/OpenClaw`: report operational risk, stale receipts, blocked queues,
  and owner decisions as explicit open loops.
- `UCL Placement`: track supervisor/admin follow-ups, logs, forms, deadlines,
  reflections, and preparation. Preserve clinical and organizational
  confidentiality. Turn vague pressure into the next concrete action and the
  evidence source that justifies it.
- `UCL Dissertation`: track milestones, ethics/admin actions, literature review,
  data/analysis, draft sections, supervisor follow-ups, and submission
  deadlines. Ask before changing direction, methods, data handling, or
  submission strategy.
- `Exams/Coursework`: start from local UCL materials and Moodle mirrors for
  study work; verify deadlines/admin facts through live/authenticated evidence
  or mark them unverified. Convert requirements into a dated revision or
  production plan.
