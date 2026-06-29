# frozen_string_literal: true

require_relative "case_loader"
require_relative "coverage_scan"
require_relative "judge_command"
require_relative "promotion_gate"
require_relative "scoring"

module EvaluatorPromotion
  module Runner
    module_function

    def evaluate(
      candidate:,
      case_roots:,
      judge_argv:,
      timeout_seconds:,
      coverage_terms: [],
      coverage_surfaces: [],
      unavailable_tools: [],
      confidentiality_failures: []
    )
      cases = CaseLoader.load_roots(case_roots)
      judge_result =
        begin
          JudgeCommand.run(
            argv: judge_argv,
            cases: cases,
            timeout_seconds: timeout_seconds,
          )
        rescue JudgeCommand::ExecutionError => e
          JudgeCommand::Result.new(
            status: "failed",
            payload: {
              "error" => e.message,
              "scores" => { "operability" => 0.0 },
            },
            stderr: "",
          )
        end

      return inoperable_report(candidate, cases, judge_result) unless judge_result.success?

      scorecard = Scoring.score(cases: cases, judge_payload: judge_result.payload)
      coverage_matches = CoverageScan.scan(
        candidate_terms: coverage_terms,
        surfaces: coverage_surfaces,
      )
      decision = PromotionGate.decide(
        scorecard: scorecard,
        coverage_matches: coverage_matches,
        unavailable_tools: unavailable_tools,
        confidentiality_failures: confidentiality_failures,
      )

      {
        "candidate" => candidate,
        "recommendation" => decision.fetch("recommendation"),
        "reasons" => decision.fetch("reasons"),
        "warnings" => decision.fetch("warnings"),
        "coverage_matches" => coverage_matches,
        "unavailable_tools" => unavailable_tools,
        "cases" => sanitized_cases(cases),
        "scores" => scorecard.fetch("scores"),
        "case_results" => scorecard.fetch("case_results"),
        "blocking_failures" => scorecard.fetch("blocking_failures"),
        "judge_status" => judge_result.status,
      }
    end

    def inoperable_report(candidate, cases, judge_result)
      {
        "candidate" => candidate,
        "recommendation" => "blocked",
        "reasons" => [judge_result.payload.fetch("error", "judge command failed")],
        "warnings" => [],
        "coverage_matches" => [],
        "unavailable_tools" => [],
        "cases" => sanitized_cases(cases),
        "scores" => {
          "catch_rate" => 0.0,
          "precision" => 0.0,
          "boundary_fit" => 0.0,
          "novelty" => 0.0,
          "operability" => judge_result.payload.fetch("scores", {}).fetch("operability", 0.0),
          "maintenance_cost" => 1.0,
        },
        "case_results" => [],
        "blocking_failures" => [],
        "judge_status" => judge_result.status,
      }
    end

    def sanitized_cases(cases)
      cases.map do |example|
        {
          "case_id" => example.case_id,
          "source_class" => example.source_class,
          "lane" => example.lane,
          "evidence_surfaces" => example.evidence_surfaces,
          "confidentiality_level" => example.confidentiality_level,
        }
      end
    end
  end
end
