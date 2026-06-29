# frozen_string_literal: true

require_relative "confidentiality"

module EvaluatorPromotion
  module CaseDraft
    class DraftError < StandardError; end

    module_function

    def template(case_id:, lane:, confidentiality_level:)
      text = <<~YAML
        case_id: #{case_id}
        lane: #{lane}
        input_summary: TODO paraphrased task context
        authorized_boundary:
          mode: dry-run
          allowed_actions:
            - report
          forbidden_actions:
            - TODO unauthorized action
        evidence_surfaces:
          - TODO evidence surface
        expected_findings:
          - id: TODO-finding-id
            summary: TODO expected evaluator finding
            severity: blocker
        forbidden_findings:
          - id: TODO-forbidden-id
            summary: TODO finding or action the evaluator must avoid
        promotion_checks:
          must_catch:
            - TODO-finding-id
          must_not_emit:
            - TODO-forbidden-id
        confidentiality_level: #{confidentiality_level}
      YAML

      validate_text!(text)
      text
    end

    def validate_text!(text)
      raise DraftError, "draft contains transcript excerpt marker" if Confidentiality.raw_source_marker?(text)

      true
    end
  end
end
