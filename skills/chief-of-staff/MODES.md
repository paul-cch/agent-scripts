# Chief Of Staff Modes

Read the matching branch before the final response. If a request spans branches,
run the control loop once, then use the branch shape that best serves the user.

## Daily Brief / Weekly Review

Use this for daily command-center, morning brief, or weekly review asks. Check
only the sources needed for today's concrete next actions. Prefer life/UCL first
and surface Homelab/OpenClaw only when urgent, blocking, or highly actionable.

For daily command-center output, return exactly:

- `Now`: the single best next action.
- `Today`: fixed commitments, deadlines, and immediate work.
- `Waiting`: blockers, waiting-on items, and approval needs.
- `Do not touch`: lanes deliberately left alone.
- `Receipt`: checked sources, route gaps, and any draft/proposal artifacts.

For fuller weekly reviews, add deadlines and immovable commitments for the next
7 and 14 days, active repo queues needing owner action, academic deliverables,
tasks to drop/defer/clarify, and one recommended weekly focus.

## Autonomous Work Sprint

Use this when the user asks the Chief of Staff to work, prepare, advance, or
reduce load. Pick the highest-leverage reversible next actions, create/reuse or
steer workers where useful, and start the work. Stop at the approval line.

Return:

- `Workers`: active, blocked, completed, and newly assigned lanes.
- `Started`: work actually begun or prepared.
- `Drafts ready`: local paths or draft text, with intended destination.
- `Needs approval`: exact send/publish/apply/mutate action and why.
- `Blocked`: missing source, credential, bridge, or decision.
- `Next autonomous step`: what can continue without approval.

## Heartbeat / Monitor

Refresh in-scope sources and active workers, compare with the last
known/reportable state when available, and report only new, changed, blocked, or
approval-needed items unless the user asks for a full digest. Prepare reversible
drafts opportunistically when obvious.

Include a compact `Heartbeat receipt`: checked sources, deltas, drafts prepared,
worker states, blocked routes, and approval asks.

## Open Loops

Classify each loop as:

- `Owed by me`
- `Waiting on someone else`
- `Needs decision`
- `Stale or maybe done`

Prefer a next action, owner, and due/refresh date. When the user asks to capture
tasks, use the relevant task skill and verify read-back.

## Meeting Prep / Project Pulse

Return:

- current state from checked files, repo status, queue, or docs;
- purpose and desired decision when meeting-shaped;
- known context, unresolved questions, suggested agenda, and likely follow-ups;
- blockers and decisions needed;
- next autonomous action;
- what not to touch without approval.

For GitHub queues, route through `$github-project-triage` or
`$maintainer-orchestrator` instead of duplicating their rules. For UCL/course
pulses, report whether evidence came from local course materials, a Moodle
mirror, live/authenticated deadline proof, or an unverified gap.

## Follow-Up Drafts

Draft concise text and label it as a draft. Do not send or post without explicit
approval. Keep drafts free of secrets and unnecessary private detail.
