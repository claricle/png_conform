# frozen_string_literal: true

require_relative "base_reporter"
require_relative "../yaml_io"

module PngConform
  module Reporters
    # YAML reporter - outputs complete file analysis in YAML format
    # Proper Model → Formatter pattern
    # Receives FileAnalysis model and formats it (no analysis done here)
    class YamlReporter < BaseReporter
      def report(file_analysis)
        # Yeptris does not fold long scalars, so long lines stay on one line.
        write_line(PngConform::YamlIO.dump(file_analysis.to_h))
      end
    end
  end
end
