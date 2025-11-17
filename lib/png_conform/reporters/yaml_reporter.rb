# frozen_string_literal: true

require_relative "base_reporter"
require "yaml"

module PngConform
  module Reporters
    # YAML reporter - outputs complete file analysis in YAML format
    # Proper Model → Formatter pattern
    # Receives FileAnalysis model and formats it (no analysis done here)
    class YamlReporter < BaseReporter
      def report(file_analysis)
        # Simple formatting - model knows how to serialize itself
        write_line(file_analysis.to_h.to_yaml)
      end
    end
  end
end
