# frozen_string_literal: true

module EvaluatorPromotion
  module Confidentiality
    RAW_SOURCE_PATTERNS = [
      /raw transcript excerpt/i,
      /transcript excerpt/i,
      /verbatim transcript/i,
    ].freeze

    module_function

    def raw_source_marker?(text)
      RAW_SOURCE_PATTERNS.any? { |pattern| text.to_s.match?(pattern) }
    end
  end
end
