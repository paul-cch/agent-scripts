# frozen_string_literal: true

require_relative "../test_helper"
require "rbconfig"
require "evaluator_promotion/case_loader"
require "evaluator_promotion/judge_command"

class EvaluatorPromotionJudgeCommandTest < Minitest::Test
  FAKE_JUDGE = File.join(ROOT, "test", "fixtures", "evaluator_promotion", "fake_judge.rb")
  PUBLIC_CASES = File.join(ROOT, "evals", "agent-promotion", "cases", "public")

  def test_run_passes_case_bundle_to_argv_judge_and_removes_tempfile
    result = EvaluatorPromotion::JudgeCommand.run(
      argv: [RbConfig.ruby, FAKE_JUDGE, "pass"],
      cases: public_cases,
      timeout_seconds: 2,
    )

    assert_predicate result, :success?
    assert_equal public_cases.length, result.payload.fetch("results").length
    refute File.exist?(result.payload.fetch("bundle_path_seen"))
  end

  def test_malformed_json_raises_and_removes_tempfile
    error = assert_raises(EvaluatorPromotion::JudgeCommand::ExecutionError) do
      EvaluatorPromotion::JudgeCommand.run(
        argv: [RbConfig.ruby, FAKE_JUDGE, "malformed"],
        cases: public_cases,
        timeout_seconds: 2,
      )
    end

    assert_includes error.message, "invalid judge JSON"
    refute File.exist?(error.bundle_path)
  end

  def test_timeout_returns_inoperable_result
    result = EvaluatorPromotion::JudgeCommand.run(
      argv: [RbConfig.ruby, FAKE_JUDGE, "sleep"],
      cases: public_cases,
      timeout_seconds: 0.1,
    )

    refute_predicate result, :success?
    assert_equal "timeout", result.status
    assert_equal 0.0, result.payload.fetch("scores").fetch("operability")
  end

  def test_background_child_inheriting_pipes_does_not_hang
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = EvaluatorPromotion::JudgeCommand.run(
      argv: [RbConfig.ruby, FAKE_JUDGE, "background-pipe"],
      cases: public_cases,
      timeout_seconds: 1,
    )
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    assert_operator elapsed, :<, 1.5
    assert_predicate result, :success?
  end

  def test_string_command_is_rejected_instead_of_shell_interpolated
    error = assert_raises(ArgumentError) do
      EvaluatorPromotion::JudgeCommand.run(
        argv: "#{RbConfig.ruby} #{FAKE_JUDGE} pass; echo unsafe",
        cases: public_cases,
        timeout_seconds: 2,
      )
    end

    assert_includes error.message, "argv array"
  end

  def test_missing_judge_executable_returns_inoperable_result
    result = EvaluatorPromotion::JudgeCommand.run(
      argv: [File.join(ROOT, "tmp", "missing-evaluator-judge")],
      cases: public_cases,
      timeout_seconds: 2,
    )

    refute_predicate result, :success?
    assert_equal "failed", result.status
    assert_equal 0.0, result.payload.fetch("scores").fetch("operability")
    assert_includes result.payload.fetch("error"), "unavailable"
  end

  private

  def public_cases
    @public_cases ||= EvaluatorPromotion::CaseLoader.load_roots([PUBLIC_CASES])
  end
end
