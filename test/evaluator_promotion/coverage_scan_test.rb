# frozen_string_literal: true

require_relative "../test_helper"
require "fileutils"
require "tmpdir"
require "evaluator_promotion/coverage_scan"

class EvaluatorPromotionCoverageScanTest < Minitest::Test
  def test_duplicate_rule_in_agents_md_is_reported
    Dir.mktmpdir do |dir|
      path = File.join(dir, "AGENTS.MD")
      File.write(path, "Always check live proof first before changing durable instructions.\n")

      matches = EvaluatorPromotion::CoverageScan.scan(
        candidate_terms: ["live proof first"],
        surfaces: [path],
      )

      assert_equal 1, matches.length
      assert_equal "AGENTS.MD", matches.first.fetch("surface")
      assert_equal "live proof first", matches.first.fetch("term")
    end
  end

  def test_scan_includes_explicit_skill_fixture_without_reading_unlisted_home_paths
    Dir.mktmpdir do |dir|
      included = File.join(dir, "skills", "sample", "SKILL.md")
      unlisted = File.join(dir, "home", "AGENTS.MD")
      FileUtils.mkdir_p(File.dirname(included))
      FileUtils.mkdir_p(File.dirname(unlisted))
      File.write(included, "Use source runtime boundary checks before promotion.\n")
      File.write(unlisted, "source runtime boundary\n")

      matches = EvaluatorPromotion::CoverageScan.scan(
        candidate_terms: ["source runtime boundary"],
        surfaces: [File.dirname(File.dirname(included))],
      )

      assert_equal ["skills/sample/SKILL.md"], matches.map { |match| match.fetch("surface") }
      refute_includes matches.map { |match| match.fetch("surface") }.join("\n"), dir
    end
  end
end
