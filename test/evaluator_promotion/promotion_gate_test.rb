# frozen_string_literal: true

require_relative "../test_helper"
require "evaluator_promotion/promotion_gate"

class EvaluatorPromotionPromotionGateTest < Minitest::Test
  def test_clean_candidate_is_recommended
    decision = EvaluatorPromotion::PromotionGate.decide(scorecard: scorecard)

    assert_equal "recommended", decision.fetch("recommendation")
    assert_empty decision.fetch("reasons")
  end

  def test_minor_maintenance_cost_concern_does_not_block_clean_candidate
    decision = EvaluatorPromotion::PromotionGate.decide(
      scorecard: scorecard("maintenance_cost" => 0.75),
    )

    assert_equal "recommended", decision.fetch("recommendation")
    assert_includes decision.fetch("warnings").join("\n"), "maintenance"
  end

  def test_duplicate_coverage_blocks_and_names_surface
    decision = EvaluatorPromotion::PromotionGate.decide(
      scorecard: scorecard,
      coverage_matches: [{ "surface" => "AGENTS.MD", "term" => "live proof first" }],
    )

    assert_equal "blocked", decision.fetch("recommendation")
    assert_includes decision.fetch("reasons").join("\n"), "AGENTS.MD"
  end

  def test_boundary_failure_blocks_regardless_of_catch_rate
    decision = EvaluatorPromotion::PromotionGate.decide(
      scorecard: scorecard("catch_rate" => 0.9, "boundary_fit" => 0.0),
    )

    assert_equal "blocked", decision.fetch("recommendation")
    assert_includes decision.fetch("reasons").join("\n"), "boundary"
  end

  def test_unavailable_tool_blocks_promotion
    decision = EvaluatorPromotion::PromotionGate.decide(
      scorecard: scorecard,
      unavailable_tools: ["model-api-key"],
    )

    assert_equal "blocked", decision.fetch("recommendation")
    assert_includes decision.fetch("reasons").join("\n"), "model-api-key"
  end

  private

  def scorecard(overrides = {})
    {
      "scores" => {
        "catch_rate" => 1.0,
        "precision" => 1.0,
        "boundary_fit" => 1.0,
        "novelty" => 1.0,
        "operability" => 1.0,
        "maintenance_cost" => 0.2,
      }.merge(overrides),
      "blocking_failures" => [],
    }
  end
end
