# frozen_string_literal: true

require_relative "base_reporter"

module PngConform
  module Reporters
    # Color reporter - wraps another reporter to add ANSI color support (-c flag)
    # Decorator pattern to add color to any reporter
    class ColorReporter < BaseReporter
      # ANSI color codes
      COLORS = {
        red: "\e[31m",
        green: "\e[32m",
        yellow: "\e[33m",
        blue: "\e[34m",
        magenta: "\e[35m",
        cyan: "\e[36m",
        reset: "\e[0m",
      }.freeze

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

      # Override colorize to actually apply colors
      def colorize(text, color)
        return text unless @colorize_enabled
        return text unless COLORS.key?(color)

        "#{COLORS[color]}#{text}#{COLORS[:reset]}"
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
