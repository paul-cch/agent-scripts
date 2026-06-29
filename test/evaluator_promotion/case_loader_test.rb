# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "yaml"
require "evaluator_promotion/case_loader"

class EvaluatorPromotionCaseLoaderTest < Minitest::Test
  def test_empty_case_directory_is_not_success
    Dir.mktmpdir do |dir|
      error = assert_raises(EvaluatorPromotion::CaseLoader::ValidationError) do
        EvaluatorPromotion::CaseLoader.load_roots([dir])
      end

      assert_includes error.message, "no case files"
    end
  end

  def test_invalid_yaml_names_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "broken.yml")
      File.write(path, "case_id: [")

      error = assert_raises(EvaluatorPromotion::CaseLoader::ValidationError) do
        EvaluatorPromotion::CaseLoader.load_roots([dir])
      end

      assert_includes error.message, "broken.yml"
    end
  end

  def test_duplicate_case_ids_across_roots_are_rejected
    Dir.mktmpdir do |first_root|
      Dir.mktmpdir do |second_root|
        write_case(File.join(first_root, "one.yml"), "duplicate-case")
        write_case(File.join(second_root, "two.yml"), "duplicate-case")

        error = assert_raises(EvaluatorPromotion::CaseLoader::ValidationError) do
          EvaluatorPromotion::CaseLoader.load_roots([first_root, second_root])
        end

        assert_includes error.message, "duplicate case_id: duplicate-case"
      end
    end
  end

  def test_non_string_case_id_is_rejected_before_sorting
    Dir.mktmpdir do |first_root|
      Dir.mktmpdir do |second_root|
        write_case(File.join(first_root, "one.yml"), "normal-case")
        write_case(File.join(second_root, "two.yml"), 1)

        error = assert_raises(EvaluatorPromotion::CaseLoader::ValidationError) do
          EvaluatorPromotion::CaseLoader.load_roots([first_root, second_root])
        end

        assert_includes error.message, "case_id must be a non-empty string"
      end
    end
  end

  def test_promotion_check_ids_must_be_strings
    Dir.mktmpdir do |dir|
      write_case(
        File.join(dir, "case.yml"),
        "bad-checks",
        "promotion_checks" => {
          "must_catch" => ["catch-duplicate"],
          "must_not_emit" => [1],
        },
      )

      error = assert_raises(EvaluatorPromotion::CaseLoader::ValidationError) do
        EvaluatorPromotion::CaseLoader.load_roots([dir])
      end

      assert_includes error.message, "promotion_checks.must_not_emit must be a string array"
    end
  end

  private

  def write_case(path, case_id, overrides = {})
    File.write(
      path,
      valid_case(case_id).merge(overrides).to_yaml,
    )
  end

  def valid_case(case_id)
    {
      "case_id" => case_id,
      "lane" => "self-improve",
      "input_summary" => "Candidate duplicates an existing rule.",
      "authorized_boundary" => {
        "mode" => "dry-run",
        "allowed_actions" => ["report"],
        "forbidden_actions" => ["edit instructions"],
      },
      "evidence_surfaces" => ["source"],
      "expected_findings" => [
        {
          "id" => "catch-duplicate",
          "summary" => "Existing coverage should block promotion.",
          "severity" => "blocker",
        },
      ],
      "forbidden_findings" => [
        {
          "id" => "apply-directly",
          "summary" => "Do not apply directly.",
        },
      ],
      "promotion_checks" => {
        "must_catch" => ["catch-duplicate"],
        "must_not_emit" => ["apply-directly"],
      },
      "confidentiality_level" => "private",
    }
  end
end
