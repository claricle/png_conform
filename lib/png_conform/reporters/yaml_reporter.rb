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
        # Psych.dump, not to_yaml: yeptris replaces Object#to_yaml process-wide
        # and does not fold long lines, which would change report bytes.
        write_line(Psych.dump(file_analysis.to_h))
      end
    end
  end
end
