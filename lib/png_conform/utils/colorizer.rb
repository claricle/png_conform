# frozen_string_literal: true

require "paint"

module PngConform
  module Utils
    # Colorization utility using the Paint gem
    #
    # Provides a centralized colorization service for terminal output.
    # Wraps the Paint gem with semantic method names and caching.
    #
    # @example Basic usage
    #   Colorizer.success("Success message")
    #   Colorizer.error("Error message")
    #   Colorizer.warning("Warning message", bold: true)
    #
    class Colorizer
      class << self
        # Check if colorization is enabled
        #
        # @return [Boolean] true if colors are enabled
        def enabled?
          Paint.mode != 0
        end

        # Enable or disable colorization
        #
        # @param value [Boolean] true to enable, false to disable
        def enabled=(value)
          Paint.mode = value ? Paint.detect_mode : 0
        end

        # Colorize text as success (green)
        #
        # @param text [String] Text to colorize
        # @param bold [Boolean] Whether to use bold formatting
        # @return [String] Colorized text
        def success(text, bold: false)
          colorize(text, :green, bold: bold)
        end

        # Colorize text as error (red)
        #
        # @param text [String] Text to colorize
        # @param bold [Boolean] Whether to use bold formatting
        # @return [String] Colorized text
        def error(text, bold: false)
          colorize(text, :red, bold: bold)
        end

        # Colorize text as warning (yellow)
        #
        # @param text [String] Text to colorize
        # @param bold [Boolean] Whether to use bold formatting
        # @return [String] Colorized text
        def warning(text, bold: false)
          colorize(text, :yellow, bold: bold)
        end

        # Colorize text as info (blue)
        #
        # @param text [String] Text to colorize
        # @param bold [Boolean] Whether to use bold formatting
        # @return [String] Colorized text
        def info(text, bold: false)
          colorize(text, :blue, bold: bold)
        end

        # Colorize text with bold formatting
        #
        # @param text [String] Text to colorize
        # @param color [Symbol] Color to use
        # @return [String] Colorized text
        def bold(text, color = nil)
          return Paint[text, :bold] unless color

          Paint[text, color, :bold]
        end

        # Colorize text with a specific color
        #
        # @param text [String] Text to colorize
        # @param color [Symbol] Color to use
        # @param bold [Boolean] Whether to use bold formatting
        # @return [String] Colorized text
        def colorize(text, color, bold: false)
          return text.to_s unless enabled?

          if bold
            Paint[text, color, :bold]
          else
            Paint[text, color]
          end
        end

        # Colorize text based on priority
        #
        # @param text [String] Text to colorize
        # @param priority [Symbol] Priority (:high, :medium, :low)
        # @return [String] Colorized text
        def priority(text, priority:)
          case priority
          when :high
            error(text, bold: true)
          when :medium
            warning(text, bold: true)
          when :low
            info(text)
          else
            text.to_s
          end
        end

        # Get a checkmark symbol (with color)
        #
        # @param success [Boolean] Whether the check should be green
        # @return [String] Colored checkmark
        def checkmark(success: true)
          if success
            success("✓")
          else
            error("✗")
          end
        end

        # Remove all color codes from text
        #
        # @param text [String] Text to uncolorize
        # @return [String] Plain text
        def uncolorize(text)
          Paint.unpaint(text)
        end

        # Apply multiple colorizations to different parts of text
        #
        # @param template [String] Template with %{key} placeholders
        # @param substitutions [Hash] Hash of key => [text, color] pairs
        # @return [String] Colorized text
        # @example
        #   Colorizer.template("%{greeting} %{name}",
        #     greeting: ["Hello", :green],
        #     name: ["World", :blue])
        def template(template, substitutions)
          Paint[template, substitutions]
        end
      end
    end
  end
end
