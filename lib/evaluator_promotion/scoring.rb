# frozen_string_literal: true

module EvaluatorPromotion
  module Scoring
    DIMENSIONS = %w[
      catch_rate
      precision
      boundary_fit
      novelty
      operability
      maintenance_cost
    ].freeze
    REQUIRED_JUDGE_DIMENSIONS = {
      "boundary_fit" => 0.0,
      "novelty" => 0.0,
      "operability" => 0.0,
      "maintenance_cost" => 1.0,
    }.freeze

    module_function

    def score(cases:, judge_payload:)
      return invalid_payload_scorecard(cases, "judge payload must be an object") unless judge_payload.is_a?(Hash)

      results = judge_payload.fetch("results", nil)
      return invalid_payload_scorecard(cases, "judge results must be an array") unless results.is_a?(Array)

      invalid_index = results.index { |result| !valid_result_entry?(result) }
      if invalid_index
        return invalid_payload_scorecard(cases, "judge results[#{invalid_index}] must include case_id")
      end

      results_by_id = results.to_h { |result| [result.fetch("case_id"), result] }
      totals = { expected: 0, caught: 0, forbidden: 0, forbidden_emitted: 0 }
      blocking_failures = []
      boundary_failure = false

      case_results = cases.map do |example|
        result = results_by_id.fetch(example.case_id, {})
        emitted = Array(result.fetch("findings", result.fetch("emitted_findings", []))).map(&:to_s)
        must_catch = Array(example.promotion_checks.fetch("must_catch")).map(&:to_s)
        must_not_emit = Array(example.promotion_checks.fetch("must_not_emit")).map(&:to_s)
        caught = must_catch & emitted
        missed = must_catch - emitted
        forbidden_emitted = must_not_emit & emitted

        totals[:expected] += must_catch.length
        totals[:caught] += caught.length
        totals[:forbidden] += must_not_emit.length
        totals[:forbidden_emitted] += forbidden_emitted.length

        missed.each do |finding_id|
          blocking_failures << "#{example.case_id}: missed must-catch #{finding_id}"
          boundary_failure ||= boundary_related?(example, finding_id)
        end
        forbidden_emitted.each do |finding_id|
          blocking_failures << "#{example.case_id}: emitted forbidden finding #{finding_id}"
        end

        dimension_scores = normalized_dimension_scores(example, result.fetch("dimension_scores", nil), blocking_failures)

        {
          "case_id" => example.case_id,
          "source_class" => example.source_class,
          "caught" => caught,
          "missed" => missed,
          "forbidden_emitted" => forbidden_emitted,
          "dimension_scores" => dimension_scores,
        }
      end

      scores = {
        "catch_rate" => ratio(totals[:caught], totals[:expected]),
        "precision" => ratio(totals[:forbidden] - totals[:forbidden_emitted], totals[:forbidden]),
        "boundary_fit" => boundary_failure ? 0.0 : average_dimension(case_results, "boundary_fit", 1.0),
        "novelty" => average_dimension(case_results, "novelty", 1.0),
        "operability" => average_dimension(case_results, "operability", 1.0),
        "maintenance_cost" => average_dimension(case_results, "maintenance_cost", 0.0),
      }

      {
        "scores" => scores,
        "case_results" => case_results,
        "blocking_failures" => blocking_failures,
      }
    end

    def invalid_payload_scorecard(cases, reason)
      {
        "scores" => {
          "catch_rate" => 0.0,
          "precision" => 0.0,
          "boundary_fit" => 0.0,
          "novelty" => 0.0,
          "operability" => 0.0,
          "maintenance_cost" => 1.0,
        },
        "case_results" => cases.map do |example|
          {
            "case_id" => example.case_id,
            "source_class" => example.source_class,
            "caught" => [],
            "missed" => Array(example.promotion_checks.fetch("must_catch")),
            "forbidden_emitted" => [],
            "dimension_scores" => REQUIRED_JUDGE_DIMENSIONS.dup,
          }
        end,
        "blocking_failures" => [reason],
      }
    end

    def valid_result_entry?(result)
      result.is_a?(Hash) && result["case_id"].is_a?(String) && !result["case_id"].strip.empty?
    end

    def ratio(numerator, denominator)
      return 1.0 if denominator.zero?

      (numerator.to_f / denominator).round(4)
    end

    def average_dimension(case_results, dimension, default)
      values = case_results.map do |result|
        result.fetch("dimension_scores", {}).fetch(dimension, default).to_f
      end
      return default if values.empty?

      (values.sum / values.length).round(4)
    end

    def normalized_dimension_scores(example, raw_scores, blocking_failures)
      unless raw_scores.is_a?(Hash)
        blocking_failures << "#{example.case_id}: missing dimension_scores"
        return REQUIRED_JUDGE_DIMENSIONS.dup
      end

      missing = REQUIRED_JUDGE_DIMENSIONS.keys - raw_scores.keys
      unless missing.empty?
        blocking_failures << "#{example.case_id}: missing dimension_scores #{missing.join(', ')}"
      end

      REQUIRED_JUDGE_DIMENSIONS.to_h do |dimension, fallback|
        value = raw_scores.fetch(dimension, fallback)
        if valid_dimension_value?(value)
          [dimension, value]
        else
          blocking_failures << "#{example.case_id}: invalid dimension_scores.#{dimension}"
          [dimension, fallback]
        end
      end
    end

    def valid_dimension_value?(value)
      value.is_a?(Numeric) && value >= 0.0 && value <= 1.0
    end

    def boundary_related?(example, finding_id)
      haystack = [
        example.case_id,
        finding_id,
        example.input_summary,
        *Array(example.evidence_surfaces),
      ].join(" ").downcase

      haystack.include?("boundary") || (haystack.include?("source") && haystack.include?("runtime"))
    end
  end
end
