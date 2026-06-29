# frozen_string_literal: true

require "json"

module EvaluatorPromotion
  module ReportWriter
    module_function

    def read(path)
      JSON.parse(File.read(path))
    rescue JSON::ParserError => e
      raise ArgumentError, "#{path}: invalid JSON: #{e.message}"
    end

    def compact_summary(report)
      lines = []
      lines << "candidate: #{report.fetch("candidate", "unknown")}"
      lines << "recommendation: #{report.fetch("recommendation", "unknown")}"
      lines << "cases: #{case_count_summary(report.fetch("cases", []))}"

      scores = report.fetch("scores", {})
      lines << "scores: #{format_scores(scores)}" unless scores.empty?
      lines.join("\n")
    end

    def case_count_summary(cases)
      counts = cases.map { |example| example.fetch("source_class", "unknown") }.tally
      details = counts.sort.map { |source, count| "#{source}: #{count}" }.join(", ")
      details.empty? ? "#{cases.length}" : "#{cases.length} (#{details})"
    end

    def format_scores(scores)
      scores.sort.map { |name, value| "#{name}=#{value}" }.join(", ")
    end
  end
end
