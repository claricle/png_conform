# frozen_string_literal: true

require_relative "base_reporter"
require_relative "../utils/colorizer"

module PngConform
  module Reporters
    # Color reporter - wraps another reporter to add ANSI color support (-c flag)
    # Decorator pattern to add color to any reporter
    class ColorReporter < BaseReporter
      attr_reader :wrapped_reporter

      # @param wrapped_reporter [BaseReporter] The reporter to wrap with colors
      def initialize(wrapped_reporter)
        super(wrapped_reporter.output, colorize: true)
        @wrapped_reporter = wrapped_reporter
      end

      def report(file_analysis)
        # Temporarily enable colorization
        @colorize_enabled = true
        wrapped_reporter.report(file_analysis)
        @colorize_enabled = false
      end

      def report_all(file_analyses)
        @colorize_enabled = true
        wrapped_reporter.report_all(file_analyses)
        @colorize_enabled = false
      end

      protected

      # Override colorize to use Colorizer class
      def colorize(text, color)
        return text unless @colorize_enabled

        case color
        when :red
          Utils::Colorizer.error(text, bold: false)
        when :green
          Utils::Colorizer.success(text, bold: false)
        when :yellow
          Utils::Colorizer.warning(text, bold: false)
        when :blue
          Utils::Colorizer.info(text, bold: false)
        when :cyan, :magenta
          # Use cyan as a neutral color for other cases
          Utils::Colorizer.colorize(text, :cyan, bold: false)
        else
          text
        end
      end

      # Determine color based on validation status
      def status_color(file_analysis)
        file_analysis.valid? ? :green : :red
      end

      # Determine color based on chunk type
      def chunk_color(chunk_type)
        # Critical chunks in one color, ancillary in another
        critical_chunks = %w[IHDR PLTE IDAT IEND]
        critical_chunks.include?(chunk_type) ? :cyan : :blue
      end
    end
  end
end
