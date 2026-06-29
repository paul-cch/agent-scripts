# Evaluator Promotion Anchors

This directory contains public-safe anchor cases for the local evaluator-promotion runner.
Cases describe the evaluator decision a future candidate should make; they do not store raw transcripts, secrets, private topology, or private organizational details.

Private Homelab and Mac-local anchors should live in an explicitly supplied private case root.
The runner may read those roots when asked, but public fixtures stay generic and reviewable in this repo.

Useful commands:

```bash
scripts/evaluator-promotion validate evals/agent-promotion/cases/public
scripts/evaluator-promotion draft my-case-id self-improve --confidentiality private
scripts/evaluator-promotion evaluate \
  --candidate "candidate label" \
  --case-root evals/agent-promotion/cases/public \
  --judge-json '["ruby","test/fixtures/evaluator_promotion/fake_judge.rb","pass"]'
```

Promotion reports are advisory. They can recommend or block a candidate, but durable edits to `AGENTS.MD`, skills, automations, external systems, or Homelab runtime state remain separate approved work.
