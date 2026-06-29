# frozen_string_literal: true

require "json"
require "rbconfig"
require "tmpdir"

ROOT = File.expand_path("../../../..", __dir__)
$LOAD_PATH.unshift(File.join(ROOT, "lib"))

require "evaluator_promotion/runner"

PUBLIC_CASES = File.join(ROOT, "evals", "agent-promotion", "cases", "public")

def judge_payload(mode, bundle_path)
  bundle = JSON.parse(File.read(bundle_path))
  cases = bundle.fetch("cases")

  case mode
  when "malformed"
    puts "{"
    return
  when "wrong-shape"
    puts JSON.generate("results" => {})
    return
  when "exit-fail"
    warn "synthetic judge failure"
    exit 65
  when "timeout"
    sleep 5
    return
  end

  puts JSON.generate("results" => synthetic_results(cases, mode))
end

def synthetic_results(cases, mode)
  cases.each_with_index.map do |example, index|
    must_catch = Array(example.fetch("promotion_checks").fetch("must_catch"))
    must_not_emit = Array(example.fetch("promotion_checks").fetch("must_not_emit"))
    findings =
      case mode
      when "miss-first"
        index.zero? ? [] : must_catch
      when "emit-forbidden"
        index.zero? ? must_catch + must_not_emit.first(1) : must_catch
      else
        must_catch
      end

    {
      "case_id" => example.fetch("case_id"),
      "findings" => findings,
      "dimension_scores" => dimension_scores(mode),
    }
  end
end

def dimension_scores(mode)
  scores = {
    "boundary_fit" => 1.0,
    "novelty" => 1.0,
    "operability" => 1.0,
    "maintenance_cost" => 0.2,
  }

  case mode
  when "low-boundary"
    scores["boundary_fit"] = 0.0
  when "high-cost"
    scores["maintenance_cost"] = 0.95
  when "warning-cost"
    scores["maintenance_cost"] = 0.75
  when "missing-dimensions"
    return {}
  end

  scores
end

def scenarios
  [
    { name: "clean-pass", mode: "pass", expected: "recommended" },
    { name: "warning-cost", mode: "warning-cost", expected: "recommended" },
    { name: "miss-first", mode: "miss-first", expected: "blocked" },
    { name: "emit-forbidden", mode: "emit-forbidden", expected: "blocked" },
    { name: "low-boundary", mode: "low-boundary", expected: "blocked" },
    { name: "high-cost", mode: "high-cost", expected: "blocked" },
    { name: "wrong-shape", mode: "wrong-shape", expected: "blocked" },
    { name: "malformed", mode: "malformed", expected: "blocked" },
    { name: "exit-fail", mode: "exit-fail", expected: "blocked" },
    { name: "timeout", mode: "timeout", expected: "blocked", timeout_seconds: 0.1 },
    { name: "missing-dimensions", mode: "missing-dimensions", expected: "blocked" },
    { name: "non-executable", mode: "pass", expected: "blocked", non_executable: true },
    { name: "duplicate-coverage", mode: "pass", expected: "blocked", duplicate_coverage: true },
    { name: "unavailable-tool", mode: "pass", expected: "blocked", unavailable_tools: ["private-mcp"] },
    { name: "confidentiality-failure", mode: "pass", expected: "blocked", confidentiality_failures: ["private root exposed"] },
  ]
end

def evaluate_scenario(scenario)
  if scenario[:non_executable]
    return Dir.mktmpdir do |dir|
      judge_path = File.join(dir, "judge.rb")
      File.write(judge_path, "#!/usr/bin/env ruby\nputs '{}'\n")
      File.chmod(0o600, judge_path)
      run_evaluator(scenario, [judge_path])
    end
  end
  if scenario[:duplicate_coverage]
    return Dir.mktmpdir do |dir|
      surface = File.join(dir, "AGENTS.MD")
      File.write(surface, "Existing rule says live proof first.\n")
      run_evaluator(
        scenario.merge(coverage_terms: ["live proof first"], coverage_surfaces: [surface]),
        [RbConfig.ruby, __FILE__, "judge", scenario.fetch(:mode)],
      )
    end
  end

  run_evaluator(scenario, [RbConfig.ruby, __FILE__, "judge", scenario.fetch(:mode)])
end

def run_evaluator(scenario, judge_argv)
  EvaluatorPromotion::Runner.evaluate(
    candidate: scenario.fetch(:name),
    case_roots: [PUBLIC_CASES],
    judge_argv: judge_argv,
    timeout_seconds: scenario.fetch(:timeout_seconds, 2),
    coverage_terms: scenario.fetch(:coverage_terms, []),
    coverage_surfaces: scenario.fetch(:coverage_surfaces, []),
    unavailable_tools: scenario.fetch(:unavailable_tools, []),
    confidentiality_failures: scenario.fetch(:confidentiality_failures, []),
  )
end

def redaction_violation?(report)
  redaction_text_violation?(JSON.generate(report))
end

def redaction_text_violation?(text)
  return true if %w[session_meta turn_context response_item].any? { |marker| text.include?(marker) }

  text.match?(%r{/(Users|private|tmp|var/folders)/})
end

def sanitized_exception(error)
  message = error.message.to_s.gsub(%r{/(?:Users|private|tmp|var/folders)/[^ \n"]+}, "[path redacted]")
  "#{error.class}: #{message}"
end

def measure
  rows = []
  crash_count = 0

  scenarios.each do |scenario|
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    report = evaluate_scenario(scenario)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    actual = report.fetch("recommendation")

    rows << {
      "name" => scenario.fetch(:name),
      "expected" => scenario.fetch(:expected),
      "actual" => actual,
      "correct" => actual == scenario.fetch(:expected),
      "redaction_violation" => redaction_violation?(report),
      "runtime_seconds" => elapsed.round(4),
    }
  rescue StandardError => e
    crash_count += 1
    error_text = sanitized_exception(e)
    rows << {
      "name" => scenario.fetch(:name),
      "expected" => scenario.fetch(:expected),
      "actual" => "crash",
      "correct" => false,
      "error" => error_text,
      "redaction_violation" => redaction_text_violation?(error_text),
      "runtime_seconds" => 0.0,
    }
  end

  summarize(rows, crash_count)
end

def summarize(rows, crash_count)
  scenario_count = rows.length
  correct_count = rows.count { |row| row.fetch("correct") }
  false_blocks = rows.count { |row| row.fetch("expected") == "recommended" && row.fetch("actual") != "recommended" }
  false_recommendations = rows.count { |row| row.fetch("expected") == "blocked" && row.fetch("actual") == "recommended" }

  {
    "decision_accuracy" => (correct_count.to_f / scenario_count).round(4),
    "unsafe_recommendations" => false_recommendations,
    "crash_count" => crash_count,
    "redaction_violations" => rows.count { |row| row.fetch("redaction_violation") },
    "clean_recommendations" => rows.count { |row| row.fetch("expected") == "recommended" && row.fetch("actual") == "recommended" },
    "scenario_count" => scenario_count,
    "false_blocks" => false_blocks,
    "false_recommendations" => false_recommendations,
    "blocked_scenarios" => rows.count { |row| row.fetch("actual") == "blocked" },
    "report_redaction_checks" => scenario_count,
    "test_runtime_seconds" => rows.sum { |row| row.fetch("runtime_seconds") }.round(4),
    "scenarios" => rows,
  }
end

if ARGV.first == "judge"
  judge_payload(ARGV.fetch(1), ARGV.fetch(2))
else
  puts JSON.pretty_generate(measure)
end
