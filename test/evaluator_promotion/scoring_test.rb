# frozen_string_literal: true

require_relative "../test_helper"
require "evaluator_promotion/case_loader"
require "evaluator_promotion/scoring"

class EvaluatorPromotionScoringTest < Minitest::Test
  PUBLIC_CASES = File.join(ROOT, "evals", "agent-promotion", "cases", "public")

  def test_full_results_emit_dimension_scores
    scorecard = EvaluatorPromotion::Scoring.score(cases: public_cases, judge_payload: perfect_payload)

    assert_equal 1.0, scorecard.fetch("scores").fetch("catch_rate")
    assert_equal 1.0, scorecard.fetch("scores").fetch("precision")
    assert_equal 1.0, scorecard.fetch("scores").fetch("boundary_fit")
    assert_equal 1.0, scorecard.fetch("scores").fetch("novelty")
    assert_equal 1.0, scorecard.fetch("scores").fetch("operability")
    assert_equal 0.2, scorecard.fetch("scores").fetch("maintenance_cost")
    assert_empty scorecard.fetch("blocking_failures")
  end

  def test_optional_rationale_can_be_omitted
    scorecard = EvaluatorPromotion::Scoring.score(cases: public_cases, judge_payload: perfect_payload)

    assert_equal public_cases.length, scorecard.fetch("case_results").length
  end

  def test_missing_dimension_scores_are_blocking_not_perfect
    payload = {
      "results" => public_cases.map do |example|
        {
          "case_id" => example.case_id,
          "findings" => example.promotion_checks.fetch("must_catch"),
        }
      end,
    }

    scorecard = EvaluatorPromotion::Scoring.score(cases: public_cases, judge_payload: payload)

    assert_equal 0.0, scorecard.fetch("scores").fetch("operability")
    assert_equal 1.0, scorecard.fetch("scores").fetch("maintenance_cost")
    assert_includes scorecard.fetch("blocking_failures").join("\n"), "dimension_scores"
  end

  def test_invalid_result_schema_is_blocking_not_an_exception
    scorecard = EvaluatorPromotion::Scoring.score(
      cases: public_cases,
      judge_payload: { "results" => {} },
    )

    assert_equal 0.0, scorecard.fetch("scores").fetch("operability")
    assert_equal 1.0, scorecard.fetch("scores").fetch("maintenance_cost")
    assert_includes scorecard.fetch("blocking_failures").join("\n"), "judge results must be an array"
  end

  def test_non_object_judge_payload_is_blocking_not_an_exception
    scorecard = EvaluatorPromotion::Scoring.score(
      cases: public_cases,
      judge_payload: [],
    )

    assert_equal 0.0, scorecard.fetch("scores").fetch("operability")
    assert_includes scorecard.fetch("blocking_failures").join("\n"), "judge payload must be an object"
  end

  def test_out_of_range_dimension_scores_are_blocking
    payload = perfect_payload
    payload.fetch("results").each do |result|
      result["dimension_scores"] = {
        "boundary_fit" => 99,
        "novelty" => 1.0,
        "operability" => "yes",
        "maintenance_cost" => -1,
      }
    end

    scorecard = EvaluatorPromotion::Scoring.score(cases: public_cases, judge_payload: payload)

    assert_equal 0.0, scorecard.fetch("scores").fetch("boundary_fit")
    assert_equal 0.0, scorecard.fetch("scores").fetch("operability")
    assert_equal 1.0, scorecard.fetch("scores").fetch("maintenance_cost")
    assert_includes scorecard.fetch("blocking_failures").join("\n"), "invalid dimension_scores"
  end

  def test_boundary_must_catch_failure_blocks_even_when_aggregate_catch_rate_is_high
    payload = perfect_payload
    homelab = payload.fetch("results").find { |result| result.fetch("case_id") == "homelab-source-vs-runtime" }
    homelab["findings"] = []

    scorecard = EvaluatorPromotion::Scoring.score(cases: public_cases, judge_payload: payload)

    assert_operator scorecard.fetch("scores").fetch("catch_rate"), :>, 0.5
    assert_equal 0.0, scorecard.fetch("scores").fetch("boundary_fit")
    assert_includes scorecard.fetch("blocking_failures").join("\n"), "source-runtime-boundary"
  end

  private

  def public_cases
    @public_cases ||= EvaluatorPromotion::CaseLoader.load_roots([PUBLIC_CASES])
  end

  def perfect_payload
    {
      "results" => public_cases.map do |example|
        {
          "case_id" => example.case_id,
          "findings" => example.promotion_checks.fetch("must_catch"),
          "dimension_scores" => {
            "boundary_fit" => 1.0,
            "novelty" => 1.0,
            "operability" => 1.0,
            "maintenance_cost" => 0.2,
          },
        }
      end,
    }
  end
end
