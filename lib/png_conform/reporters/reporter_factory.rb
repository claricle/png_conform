# frozen_string_literal: true

require_relative "summary_reporter"
require_relative "verbose_reporter"
require_relative "very_verbose_reporter"
require_relative "quiet_reporter"
require_relative "palette_reporter"
require_relative "text_reporter"
require_relative "color_reporter"
require_relative "yaml_reporter"
require_relative "json_reporter"

module PngConform
  module Reporters
    # Factory for creating reporter instances based on options.
    #
    # Implements the Factory pattern to provide a clean interface for
    # creating reporters with various combinations of options.
    class ReporterFactory
      # Create a reporter based on the specified options.
      #
      # @param format [String] Output format ("text", "yaml", "json")
      # @param verbose [Boolean] Whether to use verbose output
      # @param quiet [Boolean] Whether to use quiet output
      # @param verbosity [Symbol] Verbosity level (:quiet, :summary, :verbose, :very_verbose)
      # @param colorize [Boolean] Whether to colorize output (default: true)
      # @param show_palette [Boolean] Whether to show palette details
      # @param show_text [Boolean] Whether to show text chunk contents
      # @param seven_bit [Boolean] Whether to escape characters >= 128
      # @return [BaseReporter] Reporter instance
      def self.create(format: "text", verbose: false, quiet: false,
                      verbosity: nil, colorize: true, show_palette: false,
                      show_text: false, seven_bit: false, escape_mode: :none)
        # Format takes priority over verbosity
        case format
        when "yaml"
          return YamlReporter.new
        when "json"
          return JsonReporter.new
        end

        # Text reporters with verbosity levels
        reporter = if verbosity
                     case verbosity
                     when :quiet
                       QuietReporter.new($stdout, colorize: colorize)
                     when :verbose
                       VerboseReporter.new($stdout, colorize: colorize)
                     when :very_verbose
                       VeryVerboseReporter.new($stdout, colorize: colorize)
                     when :summary
                       SummaryReporter.new($stdout, colorize: colorize)
                     else
                       SummaryReporter.new($stdout, colorize: colorize)
                     end
                   elsif quiet
                     QuietReporter.new($stdout, colorize: colorize)
                   elsif verbose
                     VerboseReporter.new($stdout, colorize: colorize)
                   else
                     SummaryReporter.new($stdout, colorize: colorize)
                   end

        # Wrap with additional reporters based on options
        reporter = wrap_with_palette(reporter) if show_palette

        reporter = wrap_with_text(reporter, seven_bit, escape_mode) if show_text

        reporter = wrap_with_color(reporter) if colorize

        reporter
      end

      # Wrap a reporter with palette display functionality.
      #
      # @param reporter [BaseReporter] Reporter to wrap
      # @return [PaletteReporter] Wrapped reporter
      def self.wrap_with_palette(reporter)
        PaletteReporter.new(reporter)
      end

      # Wrap a reporter with text chunk display functionality.
      #
      # @param reporter [BaseReporter] Reporter to wrap
      # @param seven_bit [Boolean] Whether to escape characters >= 128
      # @param escape_mode [Symbol] Explicit escape mode setting
      # @return [TextReporter] Wrapped reporter
      def self.wrap_with_text(reporter, seven_bit, escape_mode)
        mode = if escape_mode == :none
                 (seven_bit ? :seven_bit : :none)
               else
                 escape_mode
               end
        TextReporter.new(reporter, escape_mode: mode)
      end

      # Wrap a reporter with color functionality.
      #
      # @param reporter [BaseReporter] Reporter to wrap
      # @return [ColorReporter] Wrapped reporter
      def self.wrap_with_color(reporter)
        ColorReporter.new(reporter)
      end

      private_class_method :wrap_with_palette, :wrap_with_text, :wrap_with_color
    end
  end
end
