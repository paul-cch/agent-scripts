# Anchor Case Schema

Each case is a YAML mapping with these required fields:

- `case_id`: stable kebab-case identifier.
- `lane`: workflow lane, such as `self-improve`, `homelab`, or `memory-curation`.
- `input_summary`: paraphrased task context.
- `authorized_boundary`: mapping with `mode`, `allowed_actions`, and `forbidden_actions`.
- `evidence_surfaces`: evidence categories the case depends on.
- `expected_findings`: findings the candidate evaluator must emit.
- `forbidden_findings`: findings or actions the candidate evaluator must not emit.
- `forbidden_findings_empty_reason`: required only when `forbidden_findings` is empty.
- `promotion_checks`: mapping with `must_catch` and `must_not_emit` arrays.
- `confidentiality_level`: `public` or `private`.

Public cases must use paraphrased, synthetic, or generic descriptions.
They must not contain raw transcript excerpts, secrets, private topology, credentials, or non-public organizational details.

