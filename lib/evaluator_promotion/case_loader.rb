# frozen_string_literal: true

require_relative "confidentiality"
require "yaml"

module EvaluatorPromotion
  class CaseLoader
    class ValidationError < StandardError; end

    Case = Struct.new(
      :path,
      :source_class,
      :case_id,
      :lane,
      :input_summary,
      :authorized_boundary,
      :evidence_surfaces,
      :expected_findings,
      :forbidden_findings,
      :forbidden_findings_empty_reason,
      :promotion_checks,
      :confidentiality_level,
      keyword_init: true,
    )

    REQUIRED_FIELDS = %w[
      case_id
      lane
      input_summary
      authorized_boundary
      evidence_surfaces
      expected_findings
      forbidden_findings
      promotion_checks
      confidentiality_level
    ].freeze

    REQUIRED_STRING_FIELDS = %w[
      case_id
      lane
      input_summary
      confidentiality_level
    ].freeze

    class << self
      def load_roots(roots)
        cases = Array(roots).flat_map { |root| load_root(root) }.sort_by(&:case_id)
        duplicate = cases.group_by(&:case_id).find { |_case_id, examples| examples.length > 1 }
        raise ValidationError, "duplicate case_id: #{duplicate.first}" if duplicate

        cases
      end

      def load_root(root)
        expanded = File.expand_path(root)
        raise ValidationError, "case root not found: #{root}" unless File.directory?(expanded)

        paths = Dir.glob(File.join(expanded, "**", "*.{yml,yaml}")).sort
        raise ValidationError, "#{root}: no case files" if paths.empty?

        paths.map do |path|
          load_file(path, source_class_for(expanded))
        end
      end

      def load_file(path, source_class)
        data = read_yaml(path)
        validate_mapping!(path, data)
        validate_required_fields!(path, data)
        validate_required_string_fields!(path, data)
        validate_authorized_boundary!(path, data["authorized_boundary"])
        validate_evidence_surfaces!(path, data["evidence_surfaces"])
        validate_findings!(path, "expected_findings", data["expected_findings"], allow_empty: false)
        validate_findings!(path, "forbidden_findings", data["forbidden_findings"], allow_empty: true)
        validate_forbidden_empty_reason!(path, data)
        validate_promotion_checks!(path, data["promotion_checks"])
        validate_confidentiality!(path, data)

        Case.new(
          path: path,
          source_class: source_class,
          case_id: data["case_id"],
          lane: data["lane"],
          input_summary: data["input_summary"],
          authorized_boundary: data["authorized_boundary"],
          evidence_surfaces: data["evidence_surfaces"],
          expected_findings: data["expected_findings"],
          forbidden_findings: data["forbidden_findings"],
          forbidden_findings_empty_reason: data["forbidden_findings_empty_reason"],
          promotion_checks: data["promotion_checks"],
          confidentiality_level: data["confidentiality_level"],
        )
      end

      private

      def read_yaml(path)
        YAML.safe_load(
          File.read(path),
          permitted_classes: [],
          permitted_symbols: [],
          aliases: false,
        )
      rescue Psych::SyntaxError => e
        raise ValidationError, "#{path}: YAML syntax error: #{e.message}"
      end

      def validate_mapping!(path, data)
        return if data.is_a?(Hash)

        raise ValidationError, "#{path}: case must be a YAML mapping"
      end

      def validate_required_fields!(path, data)
        missing = REQUIRED_FIELDS.select { |field| missing_required?(data[field]) }
        return if missing.empty?

        raise ValidationError, "#{path}: missing required field(s): #{missing.join(', ')}"
      end

      def validate_required_string_fields!(path, data)
        REQUIRED_STRING_FIELDS.each do |field|
          validate_present_string!(path, field, data[field])
        end
      end

      def validate_authorized_boundary!(path, value)
        unless value.is_a?(Hash)
          raise ValidationError, "#{path}: authorized_boundary must be a mapping"
        end

        %w[mode allowed_actions forbidden_actions].each do |field|
          raise ValidationError, "#{path}: authorized_boundary.#{field} is required" if blank?(value[field])
        end
        unless present_string_array?(value["allowed_actions"])
          raise ValidationError, "#{path}: authorized_boundary.allowed_actions must be a non-empty string array"
        end
        unless present_string_array?(value["forbidden_actions"])
          raise ValidationError, "#{path}: authorized_boundary.forbidden_actions must be a non-empty string array"
        end
        validate_present_string!(path, "authorized_boundary.mode", value["mode"])
      end

      def validate_evidence_surfaces!(path, value)
        unless present_string_array?(value)
          raise ValidationError, "#{path}: evidence_surfaces must be a non-empty string array"
        end
      end

      def validate_findings!(path, field, value, allow_empty:)
        unless value.is_a?(Array)
          raise ValidationError, "#{path}: #{field} must be an array"
        end
        if value.empty? && !allow_empty
          raise ValidationError, "#{path}: #{field} must include at least one finding"
        end

        value.each_with_index do |finding, index|
          unless finding.is_a?(Hash) && present_string?(finding["id"]) && present_string?(finding["summary"])
            raise ValidationError, "#{path}: #{field}[#{index}] must include id and summary"
          end
        end
      end

      def validate_forbidden_empty_reason!(path, data)
        return unless data["forbidden_findings"].is_a?(Array) && data["forbidden_findings"].empty?
        return if present_string?(data["forbidden_findings_empty_reason"])

        raise ValidationError, "#{path}: forbidden_findings_empty_reason required when forbidden_findings is empty"
      end

      def validate_promotion_checks!(path, value)
        unless value.is_a?(Hash)
          raise ValidationError, "#{path}: promotion_checks must be a mapping"
        end

        %w[must_catch must_not_emit].each do |field|
          next if value.key?(field) && string_array?(value[field])

          raise ValidationError, "#{path}: promotion_checks.#{field} must be a string array"
        end
        if value["must_catch"].empty?
          raise ValidationError, "#{path}: promotion_checks.must_catch must include at least one finding id"
        end
      end

      def validate_confidentiality!(path, data)
        level = data["confidentiality_level"]
        unless %w[public private].include?(level)
          raise ValidationError, "#{path}: confidentiality_level must be public or private"
        end

        return unless level == "public"

        return unless Confidentiality.raw_source_marker?(data.to_s)

        raise ValidationError, "#{path}: public case contains raw transcript marker"
      end

      def source_class_for(root)
        normalized = root.tr(File::SEPARATOR, "/")
        normalized.end_with?("/cases/public") || normalized.include?("/cases/public/") ? "public" : "private"
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      def missing_required?(value)
        value.nil? || (value.is_a?(String) && value.strip.empty?)
      end

      def validate_present_string!(path, field, value)
        return if present_string?(value)

        raise ValidationError, "#{path}: #{field} must be a non-empty string"
      end

      def present_string?(value)
        value.is_a?(String) && !value.strip.empty?
      end

      def string_array?(value)
        value.is_a?(Array) && value.all? { |item| present_string?(item) }
      end

      def present_string_array?(value)
        string_array?(value) && !value.empty?
      end
    end
  end
end
