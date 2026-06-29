# frozen_string_literal: true

module EvaluatorPromotion
  module CoverageScan
    SCANNABLE_GLOBS = [
      "**/AGENTS.MD",
      "**/AGENTS.md",
      "**/SKILL.md",
      "**/*.md",
    ].freeze

    module_function

    def scan(candidate_terms:, surfaces:)
      terms = Array(candidate_terms).map { |term| normalize(term) }.reject(&:empty?)
      return [] if terms.empty?

      files = Array(surfaces)
        .flat_map { |surface| files_for_surface(surface).map { |path| [path, surface_label(path, surface)] } }
        .uniq { |path, _label| path }
        .sort_by { |path, _label| path }

      files.flat_map do |path, label|
        text = File.read(path)
        normalized_text = normalize(text)
        normalized_lines = text.each_line.map { |line| normalize(line) }
        terms.filter_map do |term|
          next unless normalized_text.include?(term)

          {
            "surface" => label,
            "term" => term,
            "line" => matching_line(normalized_lines, term),
          }
        end
      rescue Errno::ENOENT, Errno::EACCES
        []
      end
    end

    def files_for_surface(surface)
      expanded = File.expand_path(surface)
      return [expanded] if File.file?(expanded)
      return [] unless File.directory?(expanded)

      SCANNABLE_GLOBS.flat_map do |pattern|
        Dir.glob(File.join(expanded, pattern), File::FNM_CASEFOLD)
      end.select { |path| File.file?(path) }
    end

    def surface_label(path, surface)
      expanded_path = File.expand_path(path)
      cwd = File.expand_path(Dir.pwd)
      return relative_path(expanded_path, cwd) if inside?(expanded_path, cwd)

      expanded_surface = File.expand_path(surface)
      return File.basename(expanded_path) if File.file?(expanded_surface)
      return File.join(File.basename(expanded_surface), relative_path(expanded_path, expanded_surface)) if inside?(expanded_path, expanded_surface)

      File.basename(expanded_path)
    end

    def inside?(path, root)
      path == root || path.start_with?("#{root}#{File::SEPARATOR}")
    end

    def relative_path(path, root)
      path.delete_prefix("#{root}#{File::SEPARATOR}")
    end

    def normalize(text)
      text.to_s.downcase.gsub(/\s+/, " ").strip
    end

    def matching_line(normalized_lines, normalized_term)
      normalized_lines.each.with_index(1) do |line, index|
        return index if line.include?(normalized_term)
      end
      nil
    end
  end
end
