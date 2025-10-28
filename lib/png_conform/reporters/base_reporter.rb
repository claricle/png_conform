# frozen_string_literal: true

module PngConform
  module Reporters
    # Base class for all reporters
    # Reporters consume FileAnalysis models and produce formatted output
    class BaseReporter
      attr_reader :output

      def initialize(output = $stdout, colorize: true)
        @output = output
        @colorize = colorize
      end

      # Report a single file analysis
      # Must be implemented by subclasses
      def report(file_analysis)
        raise NotImplementedError, "Subclasses must implement #report"
      end

      # Report multiple file analyses
      def report_all(file_analyses)
        file_analyses.each do |analysis|
          report(analysis)
        end
      end

      protected

      # Write a line to output
      def write_line(text = "")
        output.puts(text)
      end

      # Write text without newline
      def write(text)
        output.print(text)
      end

      # Format with color (if supported)
      def colorize(text, _color)
        # Base implementation only colorizes if @colorize is true
        # Override in ColorReporter for actual color support
        text
      end

      # Check if colorization is enabled
      def colorize?
        @colorize
      end
    end
  end
end
