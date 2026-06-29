# frozen_string_literal: true

require_relative "../test_helper"
require "rbconfig"
require "tmpdir"
require "evaluator_promotion/runner"

class EvaluatorPromotionRunnerTest < Minitest::Test
  FAKE_JUDGE = File.join(ROOT, "test", "fixtures", "evaluator_promotion", "fake_judge.rb")
  PUBLIC_CASES = File.join(ROOT, "evals", "agent-promotion", "cases", "public")

  def test_runner_loads_cases_runs_judge_and_emits_scorecard
    report = EvaluatorPromotion::Runner.evaluate(
      candidate: "fake judge",
      case_roots: [PUBLIC_CASES],
      judge_argv: [RbConfig.ruby, FAKE_JUDGE, "pass"],
      timeout_seconds: 2,
    )

    assert_equal "fake judge", report.fetch("candidate")
    assert_equal 3, report.fetch("cases").length
    assert_equal 1.0, report.fetch("scores").fetch("catch_rate")
    assert_includes report.fetch("scores").keys, "maintenance_cost"
  end

  def test_runner_marks_timeout_inoperable
    report = EvaluatorPromotion::Runner.evaluate(
      candidate: "sleepy judge",
      case_roots: [PUBLIC_CASES],
      judge_argv: [RbConfig.ruby, FAKE_JUDGE, "sleep"],
      timeout_seconds: 0.1,
    )

    assert_equal "blocked", report.fetch("recommendation")
    assert_equal 0.0, report.fetch("scores").fetch("operability")
    assert_includes report.fetch("reasons").join("\n"), "timeout"
  end

  def test_runner_marks_malformed_judge_output_inoperable
    report = EvaluatorPromotion::Runner.evaluate(
      candidate: "bad judge",
      case_roots: [PUBLIC_CASES],
      judge_argv: [RbConfig.ruby, FAKE_JUDGE, "malformed"],
      timeout_seconds: 2,
    )

    assert_equal "blocked", report.fetch("recommendation")
    assert_equal 0.0, report.fetch("scores").fetch("operability")
    assert_includes report.fetch("reasons").join("\n"), "invalid judge JSON"
  end

  def test_runner_marks_non_executable_judge_inoperable
    Dir.mktmpdir do |dir|
      judge_path = File.join(dir, "judge.rb")
      File.write(judge_path, "#!/usr/bin/env ruby\nputs '{}'\n")
      File.chmod(0o600, judge_path)

      report = EvaluatorPromotion::Runner.evaluate(
        candidate: "non executable judge",
        case_roots: [PUBLIC_CASES],
        judge_argv: [judge_path],
        timeout_seconds: 2,
      )

      assert_equal "blocked", report.fetch("recommendation")
      assert_equal 0.0, report.fetch("scores").fetch("operability")
      assert_includes report.fetch("reasons").join("\n"), "judge command unavailable"
      refute_includes report.fetch("reasons").join("\n"), judge_path
    end
  end

  def test_runner_blocks_duplicate_coverage_from_explicit_surface
    Dir.mktmpdir do |dir|
      surface = File.join(dir, "AGENTS.MD")
      File.write(surface, "Existing rule already says live proof first.\n")

      report = EvaluatorPromotion::Runner.evaluate(
        candidate: "duplicate rule",
        case_roots: [PUBLIC_CASES],
        judge_argv: [RbConfig.ruby, FAKE_JUDGE, "pass"],
        timeout_seconds: 2,
        coverage_terms: ["live proof first"],
        coverage_surfaces: [surface],
      )

      assert_equal "blocked", report.fetch("recommendation")
      assert_includes report.fetch("reasons").join("\n"), "AGENTS.MD"
      refute_includes report.fetch("reasons").join("\n"), surface
      assert_equal ["AGENTS.MD"], report.fetch("coverage_matches").map { |match| match.fetch("surface") }
    end
  end
end
