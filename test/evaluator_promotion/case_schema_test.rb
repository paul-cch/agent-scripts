# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "yaml"
require "evaluator_promotion/case_loader"

class EvaluatorPromotionCaseSchemaTest < Minitest::Test
  PUBLIC_CASES = File.join(ROOT, "evals", "agent-promotion", "cases", "public")

  def test_public_seed_cases_validate_through_loader
    cases = EvaluatorPromotion::CaseLoader.load_roots([PUBLIC_CASES])

    assert_equal(
      %w[
        homelab-source-vs-runtime
        memory-curation-judgment
        self-improve-duplicate-coverage
      ],
      cases.map(&:case_id).sort,
    )
    assert(cases.all? { |example| example.source_class == "public" })
  end

  def test_complete_case_with_source_and_runtime_evidence_validates
    Dir.mktmpdir do |dir|
      path = File.join(dir, "complete.yml")
      write_case(path, valid_case.merge("evidence_surfaces" => %w[source runtime]))

      cases = EvaluatorPromotion::CaseLoader.load_roots([dir])

      assert_equal ["complete-case"], cases.map(&:case_id)
      assert_equal %w[source runtime], cases.first.evidence_surfaces
  end
  end

  def test_empty_forbidden_findings_requires_reason
    Dir.mktmpdir do |dir|
      path = File.join(dir, "missing-reason.yml")
      write_case(path, valid_case.merge("forbidden_findings" => []))

      error = assert_raises(EvaluatorPromotion::CaseLoader::ValidationError) do
        EvaluatorPromotion::CaseLoader.load_roots([dir])
      end

      assert_includes error.message, "forbidden_findings_empty_reason"
    end
  end

  def test_empty_expected_findings_are_rejected
    Dir.mktmpdir do |dir|
      path = File.join(dir, "empty-expected.yml")
      write_case(path, valid_case.merge("expected_findings" => []))

      error = assert_raises(EvaluatorPromotion::CaseLoader::ValidationError) do
        EvaluatorPromotion::CaseLoader.load_roots([dir])
      end

      assert_includes error.message, "expected_findings"
    end
  end

  def test_empty_must_catch_checks_are_rejected
    Dir.mktmpdir do |dir|
      path = File.join(dir, "empty-must-catch.yml")
      write_case(path, valid_case.merge("promotion_checks" => { "must_catch" => [], "must_not_emit" => [] }))

      error = assert_raises(EvaluatorPromotion::CaseLoader::ValidationError) do
        EvaluatorPromotion::CaseLoader.load_roots([dir])
      end

      assert_includes error.message, "promotion_checks.must_catch"
    end
  end

  def test_empty_evidence_surfaces_are_rejected
    Dir.mktmpdir do |dir|
      path = File.join(dir, "empty-evidence.yml")
      write_case(path, valid_case.merge("evidence_surfaces" => []))

      error = assert_raises(EvaluatorPromotion::CaseLoader::ValidationError) do
        EvaluatorPromotion::CaseLoader.load_roots([dir])
      end

      assert_includes error.message, "evidence_surfaces"
    end
  end

  def test_authorized_boundary_actions_must_be_arrays
    Dir.mktmpdir do |dir|
      path = File.join(dir, "scalar-actions.yml")
      data = valid_case
      data["authorized_boundary"] = data.fetch("authorized_boundary").merge(
        "allowed_actions" => "report",
      )
      write_case(path, data)

      error = assert_raises(EvaluatorPromotion::CaseLoader::ValidationError) do
        EvaluatorPromotion::CaseLoader.load_roots([dir])
      end

      assert_includes error.message, "authorized_boundary.allowed_actions"
    end
  end

  def test_missing_authorized_boundary_names_field
    Dir.mktmpdir do |dir|
      path = File.join(dir, "missing-boundary.yml")
      data = valid_case
      data.delete("authorized_boundary")
      write_case(path, data)

      error = assert_raises(EvaluatorPromotion::CaseLoader::ValidationError) do
        EvaluatorPromotion::CaseLoader.load_roots([dir])
      end

      assert_includes error.message, "authorized_boundary"
    end
  end

  def test_public_case_rejects_private_transcript_content
    Dir.mktmpdir do |dir|
      path = File.join(dir, "private-transcript.yml")
      write_case(
        path,
        valid_case.merge(
          "input_summary" => "Raw transcript excerpt: user said private details.",
          "confidentiality_level" => "public",
        ),
      )

      error = assert_raises(EvaluatorPromotion::CaseLoader::ValidationError) do
        EvaluatorPromotion::CaseLoader.load_roots([dir])
      end

      assert_includes error.message, "raw transcript"
    end
  end

  private

  def valid_case
    {
      "case_id" => "complete-case",
      "lane" => "self-improve",
      "input_summary" => "Candidate duplicates an existing live-proof instruction.",
      "authorized_boundary" => {
        "mode" => "dry-run",
        "allowed_actions" => ["report"],
        "forbidden_actions" => ["edit instructions"],
      },
      "evidence_surfaces" => %w[source runtime],
      "expected_findings" => [
        {
          "id" => "catch-duplicate",
          "summary" => "Existing instruction coverage should block promotion.",
          "severity" => "blocker",
        },
      ],
      "forbidden_findings" => [
        {
          "id" => "apply-directly",
          "summary" => "Do not apply the proposed instruction directly.",
        },
      ],
      "promotion_checks" => {
        "must_catch" => ["catch-duplicate"],
        "must_not_emit" => ["apply-directly"],
      },
      "confidentiality_level" => "public",
    }
  end

  def write_case(path, data)
    File.write(path, "#{YAML.dump(data)}\n")
  end
end
