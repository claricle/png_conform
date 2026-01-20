# frozen_string_literal: true

require_relative "../utils/colorizer"

module PngConform
  module Reporters
    # Module providing visual elements (emojis and colors) for CLI output
    # Text reporters include this module to add visual appeal
    # Structured reporters (YAML/JSON) do not use these elements
    module VisualElements
      # Emoji definitions for consistent visual representation
      EMOJI = {
        success: "✅",
        error: "❌",
        warning: "⚠️",
        info: "ℹ️",
        chunk: "📦",
        file: "📄",
        valid_crc: "✓",
        invalid_crc: "✗",
        compression: "🗜️",
        image: "🖼️",
      }.freeze

      # Colorize text with Colorizer class
      # @param text [String] The text to colorize
      # @param color [Symbol] The color name
      # @return [String] Colorized text or original if colorization disabled
      def colorize(text, color)
        return text unless @colorize

        case color
        when :green
          Utils::Colorizer.success(text, bold: false)
        when :red
          Utils::Colorizer.error(text, bold: false)
        when :yellow
          Utils::Colorizer.warning(text, bold: false)
        when :blue
          Utils::Colorizer.info(text, bold: false)
        when :cyan
          Utils::Colorizer.colorize(text, :cyan, bold: false)
        when :gray
          Utils::Colorizer.colorize(text, :gray, bold: false)
        when :bold
          Utils::Colorizer.bold(text)
        else
          text
        end
      end

      # Get emoji for a given name
      # @param name [Symbol] The emoji name from EMOJI
      # @return [String] The emoji character or empty string
      def emoji(name)
        EMOJI[name] || ""
      end

      # Get color code for severity level
      # @param severity [String] The severity level ("error", "warning", "info")
      # @return [Symbol] The color symbol
      def color_for_severity(severity)
        case severity
        when "error" then :red
        when "warning" then :yellow
        when "info" then :blue
        else :gray
        end
      end
    end
  end
end
