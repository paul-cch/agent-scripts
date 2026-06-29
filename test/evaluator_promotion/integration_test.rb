# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require "open3"
require "rbconfig"

class EvaluatorPromotionIntegrationTest < Minitest::Test
  SCRIPT = File.join(ROOT, "scripts", "evaluator-promotion")
  FAKE_JUDGE = File.join(ROOT, "test", "fixtures", "evaluator_promotion", "fake_judge.rb")
  PUBLIC_CASES = File.join(ROOT, "evals", "agent-promotion", "cases", "public")

  def test_evaluate_cli_runs_public_fixtures_without_private_roots
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      SCRIPT,
      "evaluate",
      "--candidate", "fake judge",
      "--case-root", PUBLIC_CASES,
      "--judge-json", JSON.generate([RbConfig.ruby, FAKE_JUDGE, "pass"]),
    )

    assert_predicate status, :success?, stderr

    report = JSON.parse(stdout)
    assert_equal "recommended", report.fetch("recommendation")
    assert_equal 3, report.fetch("cases").length
    assert(report.fetch("cases").all? { |example| example.fetch("source_class") == "public" })
    assert_equal(
      %w[boundary_fit catch_rate maintenance_cost novelty operability precision],
      report.fetch("scores").keys.sort,
    )
  end

  def test_evaluate_cli_reports_malformed_judge_json_as_blocked
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      SCRIPT,
      "evaluate",
      "--candidate", "bad judge",
      "--case-root", PUBLIC_CASES,
      "--judge-json", JSON.generate([RbConfig.ruby, FAKE_JUDGE, "malformed"]),
    )

    assert_equal 3, status.exitstatus, stderr

    report = JSON.parse(stdout)
    assert_equal "blocked", report.fetch("recommendation")
    assert_equal 0.0, report.fetch("scores").fetch("operability")
    assert_includes report.fetch("reasons").join("\n"), "invalid judge JSON"
  end

  def test_evaluate_cli_reports_invalid_judge_schema_as_blocked
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      SCRIPT,
      "evaluate",
      "--candidate", "wrong shape judge",
      "--case-root", PUBLIC_CASES,
      "--judge-json", JSON.generate([RbConfig.ruby, FAKE_JUDGE, "wrong-shape"]),
    )

    assert_equal 3, status.exitstatus, stderr

    report = JSON.parse(stdout)
    assert_equal "blocked", report.fetch("recommendation")
    assert_equal 0.0, report.fetch("scores").fetch("operability")
    assert_includes report.fetch("reasons").join("\n"), "judge results must be an array"
  end

  def test_evaluate_cli_reports_non_object_judge_json_as_blocked
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      SCRIPT,
      "evaluate",
      "--candidate", "array judge",
      "--case-root", PUBLIC_CASES,
      "--judge-json", JSON.generate([RbConfig.ruby, FAKE_JUDGE, "top-array"]),
    )

    assert_equal 3, status.exitstatus, stderr

    report = JSON.parse(stdout)
    assert_equal "blocked", report.fetch("recommendation")
    assert_equal 0.0, report.fetch("scores").fetch("operability")
    assert_includes report.fetch("reasons").join("\n"), "judge payload must be an object"
  end
end
