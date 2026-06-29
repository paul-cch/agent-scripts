# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "yaml"
require "evaluator_promotion/case_loader"
require "evaluator_promotion/private_roots"

class EvaluatorPromotionPrivateRootsTest < Minitest::Test
  PUBLIC_CASES = File.join(ROOT, "evals", "agent-promotion", "cases", "public")

  def test_public_and_private_roots_load_with_source_labels
    Dir.mktmpdir do |private_root|
      File.write(File.join(private_root, "private.yml"), YAML.dump(private_case))

      roots = EvaluatorPromotion::PrivateRoots.resolve(
        public_roots: [PUBLIC_CASES],
        private_roots: [private_root],
      )
      cases = EvaluatorPromotion::CaseLoader.load_roots(roots)

      assert_equal 4, cases.length
      assert_equal 3, cases.count { |example| example.source_class == "public" }
      assert_equal 1, cases.count { |example| example.source_class == "private" }
    end
  end

  def test_missing_private_root_fails_before_loading_cases
    error = assert_raises(EvaluatorPromotion::PrivateRoots::MissingRootError) do
      EvaluatorPromotion::PrivateRoots.resolve(public_roots: [], private_roots: ["does-not-exist"])
    end

    assert_includes error.message, "private case root not found"
  end

  private

  def private_case
    {
      "case_id" => "private-homelab-case",
      "lane" => "homelab",
      "input_summary" => "Redacted private case summary.",
      "authorized_boundary" => {
        "mode" => "dry-run",
        "allowed_actions" => ["report"],
        "forbidden_actions" => ["mutate runtime"],
      },
      "evidence_surfaces" => %w[source runtime],
      "expected_findings" => [
        {
          "id" => "runtime-proof-required",
          "summary" => "Runtime proof is required.",
          "severity" => "blocker",
        },
      ],
      "forbidden_findings" => [
        {
          "id" => "accept-source-only",
          "summary" => "Do not accept source proof only.",
        },
      ],
      "promotion_checks" => {
        "must_catch" => ["runtime-proof-required"],
        "must_not_emit" => ["accept-source-only"],
      },
      "confidentiality_level" => "private",
    }
  end
end

