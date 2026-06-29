# frozen_string_literal: true

module EvaluatorPromotion
  module PrivateRoots
    class MissingRootError < StandardError; end

    module_function

    def resolve(public_roots:, private_roots:)
      normalized_private = Array(private_roots).map do |root|
        expanded = File.expand_path(root)
        raise MissingRootError, "private case root not found: #{root}" unless File.directory?(expanded)

        expanded
      end

      Array(public_roots).map { |root| File.expand_path(root) } + normalized_private
    end
  end
end
