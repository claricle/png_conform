# frozen_string_literal: true

require_relative "base_reporter"

module PngConform
  module Reporters
    # Quiet reporter - outputs only errors (-q flag)
    # Matches pngcheck -q output format
    class QuietReporter < BaseReporter
      def report(file_analysis)
        # Only output if there are errors
        return if file_analysis.valid?

        write_line(file_analysis.validation_result.error_summary)
      end
    end
  end
end
