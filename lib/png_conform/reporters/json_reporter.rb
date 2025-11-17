# frozen_string_literal: true

require_relative "base_reporter"
require "json"

module PngConform
  module Reporters
    # JSON reporter - outputs complete file analysis in JSON format
    # Proper Model → Formatter pattern
    # Receives FileAnalysis model and formats it (no analysis done here)
    class JsonReporter < BaseReporter
      def report(file_analysis)
        # Simple formatting - model knows how to serialize itself
        write_line(JSON.pretty_generate(file_analysis.to_h))
      end
    end
  end
end
