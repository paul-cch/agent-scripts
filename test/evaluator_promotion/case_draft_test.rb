# frozen_string_literal: true

require_relative "../test_helper"
require "evaluator_promotion/case_draft"

class EvaluatorPromotionCaseDraftTest < Minitest::Test
  def test_template_is_paraphrase_oriented
    text = EvaluatorPromotion::CaseDraft.template(
      case_id: "draft-case",
      lane: "self-improve",
      confidentiality_level: "private",
    )

    assert_includes text, "case_id: draft-case"
    assert_includes text, "input_summary: TODO paraphrased task context"
    refute_match(/transcript excerpt/i, text)
  end

  def test_draft_rejects_transcript_excerpt_marker
    error = assert_raises(EvaluatorPromotion::CaseDraft::DraftError) do
      EvaluatorPromotion::CaseDraft.validate_text!("input_summary: transcript excerpt from private session")
    end

    assert_includes error.message, "transcript excerpt"
  end
end

