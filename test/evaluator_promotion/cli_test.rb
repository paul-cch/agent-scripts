# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require "open3"
require "tmpdir"

class EvaluatorPromotionCliTest < Minitest::Test
  SCRIPT = File.join(ROOT, "scripts", "evaluator-promotion")
  PUBLIC_CASES = File.join(ROOT, "evals", "agent-promotion", "cases", "public")

  def test_validate_accepts_public_fixtures_and_prints_count
    stdout, stderr, status = run_cli("validate", PUBLIC_CASES)

    assert_predicate status, :success?, stderr
    assert_includes stdout, "valid cases: 3"
    assert_includes stdout, "homelab-source-vs-runtime"
    assert_includes stdout, "self-improve-duplicate-coverage"
  end

  def test_report_prints_compact_summary_without_private_text
    Dir.mktmpdir do |dir|
      report_path = File.join(dir, "report.json")
      File.write(
        report_path,
        JSON.pretty_generate(
          "candidate" => "draft evaluator",
          "recommendation" => "blocked",
          "cases" => [
            {
              "case_id" => "private-case",
              "source_class" => "private",
              "input_summary" => "sensitive private source text",
            },
          ],
          "scores" => { "catch_rate" => 0.5 },
        ),
      )

      stdout, stderr, status = run_cli("report", report_path)

      assert_predicate status, :success?, stderr
      assert_includes stdout, "candidate: draft evaluator"
      assert_includes stdout, "recommendation: blocked"
      assert_includes stdout, "cases: 1 (private: 1)"
      refute_includes stdout, "sensitive private source text"
    end
  end

  private

  def run_cli(*args)
    Open3.capture3(RbConfig.ruby, SCRIPT, *args)
  end
end

