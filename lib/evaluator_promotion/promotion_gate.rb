# frozen_string_literal: true

module EvaluatorPromotion
  module PromotionGate
    module_function

    def decide(scorecard:, coverage_matches: [], unavailable_tools: [], confidentiality_failures: [])
      scores = scorecard.fetch("scores")
      reasons = []
      warnings = []

      Array(scorecard.fetch("blocking_failures", [])).each do |failure|
        reasons << "scorecard blocking failure: #{failure}"
      end
      Array(coverage_matches).each do |match|
        reasons << "duplicate coverage in #{match.fetch("surface")}: #{match.fetch("term")}"
      end
      Array(unavailable_tools).each do |tool|
        reasons << "unavailable required tool: #{tool}"
      end
      Array(confidentiality_failures).each do |failure|
        reasons << "confidentiality failure: #{failure}"
      end

      reasons << "catch rate below required threshold" if scores.fetch("catch_rate", 0.0).to_f < 1.0
      reasons << "precision below required threshold" if scores.fetch("precision", 0.0).to_f < 1.0
      reasons << "boundary fit below required threshold" if scores.fetch("boundary_fit", 0.0).to_f < 1.0
      reasons << "novelty below required threshold" if scores.fetch("novelty", 0.0).to_f < 1.0
      reasons << "operability below required threshold" if scores.fetch("operability", 0.0).to_f < 1.0

      maintenance_cost = scores.fetch("maintenance_cost", 0.0).to_f
      if maintenance_cost >= 0.9
        reasons << "maintenance cost too high"
      elsif maintenance_cost >= 0.7
        warnings << "maintenance cost needs reviewer attention"
      end

      {
        "recommendation" => reasons.empty? ? "recommended" : "blocked",
        "reasons" => reasons,
        "warnings" => warnings,
        "coverage_matches" => coverage_matches,
        "unavailable_tools" => unavailable_tools,
      }
    end
  end
end
