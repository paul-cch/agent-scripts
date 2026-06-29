---
summary: 'Local evaluator-promotion anchors, dry-run runner, scoring dimensions, and promotion gate workflow.'
read_when:
  - Adding or reviewing evaluator-promotion anchor cases.
  - Testing self-improve, autoreview, setup-drift, memory-curation, or Homelab proof rules.
---

# Evaluator Promotion

Evaluator promotion turns known workflow failures and accepted fixes into frozen anchor cases. A candidate evaluator, checklist, or instruction proposal is run against those cases, scored, and then passed through conservative gates. Reports are advisory; they do not grant permission to edit durable instructions, skills, automations, external services, or runtime systems.

## Case Roots

Public-safe cases live in `evals/agent-promotion/cases/public`. They must be paraphrased and must not include raw transcript excerpts, credentials, private topology, private organizational details, or machine-local paths.

Private Homelab or Mac-local cases live outside the public fixture tree and are loaded only when an explicit case root is supplied. Reports include case IDs, lanes, source classes, evidence categories, scores, and gate reasons; they do not print private root paths or case summaries.

Validate public fixtures:

```bash
scripts/evaluator-promotion validate evals/agent-promotion/cases/public
```

Draft a private case template:

```bash
scripts/evaluator-promotion draft my-case-id homelab --confidentiality private
```

## Running A Dry Evaluation

The first runner uses a command judge. The command is passed as a JSON argv array and executed without shell interpolation. It receives a temporary case-bundle path as the final argv item and must print JSON with a `results` array.

Example with the hermetic fake judge:

```bash
scripts/evaluator-promotion evaluate \
  --candidate "fake judge" \
  --case-root evals/agent-promotion/cases/public \
  --judge-json '["ruby","test/fixtures/evaluator_promotion/fake_judge.rb","pass"]'
```

Add duplicate-coverage checks only with explicit surfaces. Reports show sanitized surface labels, not absolute or private scan paths:

```bash
scripts/evaluator-promotion evaluate \
  --candidate "candidate rule" \
  --case-root evals/agent-promotion/cases/public \
  --coverage-term "live proof first" \
  --coverage-surface AGENTS.MD \
  --judge-json '["ruby","test/fixtures/evaluator_promotion/fake_judge.rb","pass"]'
```

The scorecard dimensions are `catch_rate`, `precision`, `boundary_fit`, `novelty`, `operability`, and `maintenance_cost`. Promotion is blocked when must-catch anchors are missed, forbidden findings are emitted, boundary fit regresses, duplicate coverage already exists, required tools are unavailable, confidentiality fails, or the change is too costly to maintain.

## Workflow Fit

Use this lane before promoting broad evaluator or instruction changes from self-improve, `autoreview`, setup-drift, memory curation, local automation health, or Homelab/OpenClaw proof workflows. It complements those tools by checking frozen examples and duplicate coverage; it does not replace their existing authority or closeout checks.

For Homelab/OpenClaw anchors, keep source, workbench, host/runtime, GitHub, Notion mirror, local automation, and user-reported proof categories separate. A case that asks for runtime proof should fail if a candidate accepts source or workbench proof as completion.

## Validation

Run the focused suite:

```bash
scripts/test-evaluator-promotion
```

Normal closeout still uses the broader repo checks:

```bash
scripts/validate-skills
bun scripts/docs-list.ts
scripts/audit-machine-setup
```
