---
name: codex-workflow
description: "Codex workflow control plane: manage worker threads, heartbeats, /goal completion gates, PR review follow-up, scheduled check-ins, and ready-to-merge work."
---

# Codex Workflow

Use one Codex thread as the control plane for long-running work. The control thread owns topology, heartbeats, goals, review loops, and owner decisions; worker threads own implementation.

## Control Plane

- Keep exactly one control thread for the workflow unless the user explicitly splits it.
- Put substantial implementation in worker threads. The control thread reads state, assigns work, monitors, and decides the next move.
- Reuse an existing worker when it already owns the same repository or task. Create a new worker only for independent work.
- Workers must not create or manage other threads unless the user explicitly asks for nested orchestration.
- Treat the newest instruction inside each thread as authoritative before sending any steering message.

Completion criterion: the control thread has a current map of worker thread, task, goal, heartbeat cadence, stop condition, and remaining owner decision for every active lane.

## Start Workers

1. Search for the thread tools needed for the action: `create_thread`, `read_thread`, `send_message_to_thread`, `set_thread_title`, `handoff_thread`, or their current equivalents.
2. Name each worker after the live assignment, usually `<Project>: <short task>`.
3. Send the worker a concrete task plus `/goal`. The goal must include the desired end state, proof required, mutation permissions, and stop conditions.
4. Include the no-subdelegation rule when this control thread is meant to own topology.

Completion criterion: every worker has an active assignment, a matching title, and a `/goal` that makes completion checkable without reading the control thread's private reasoning.

## Add Heartbeats

Use heartbeats for work that should keep moving after the current turn: scheduled work, PR-review follow-up, CI watching, periodic check-ins, or long-running implementation.

1. Search for the automation tool before creating, updating, or deleting a heartbeat.
2. Put the heartbeat on the control thread, not on a worker, unless the user explicitly wants the worker to wake itself.
3. Write the heartbeat prompt as a state check followed by conditional action: read the worker, inspect live proof, then steer only if needed.
4. Include cadence, stop condition, and the exact surface to inspect.

Completion criterion: every heartbeat has a clear next check, a bounded action surface, and a stop condition such as "PR merged", "worker goal complete", "owner decision asked", or "blocked three checks in a row".

## Monitor

On each check-in:

1. Read the worker's latest state and newest user/delegation messages.
2. Classify the worker as `active`, `blocked`, `complete`, `idle`, or `off-course`.
3. Send nothing when an active worker has a coherent plan and is making progress.
4. Intervene only for a blocker, completed goal, idle worker, wrong scope, stale proof, failing CI, unanswered review comments, or clear deviation from the assignment.
5. When steering, send one concise next instruction and preserve the worker's local context.

Completion criterion: each monitor pass leaves every worker either progressing without interruption, assigned a specific next step, or escalated to the owner with the smallest necessary question.

## PR Review Loop

When the user wants work pushed until ready to merge:

1. Have the worker make the code/doc/test changes and push only within the user's granted permissions.
2. Run or request the available Codex review/autoreview path when the repository expects it.
3. Send actionable review findings back to the worker, with file/line references when available.
4. Repeat fix, test, push, and review until no accepted/actionable findings remain or a real blocker needs the owner.
5. Check CI and mergeability before asking for a land/delete/waiver decision.

Completion criterion: the PR is merged when authorized, or ready for the owner with proof, risks, and exact remaining choices.

## Closeout

- Stop or retire heartbeats when their stop condition is met.
- Archive or leave worker threads according to the user's thread-management preference.
- Report thread URLs/IDs, goals completed, proof checked, PR/review/CI status, and remaining owner decisions.
- Keep source proof, CI proof, runtime proof, connector effects, and user-reported completion separate.

Completion criterion: no heartbeat is left running without a reason, no worker is waiting silently, and the user can see what is done, what is ready, and what still needs a decision.
