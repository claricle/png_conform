# frozen_string_literal: true

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

      # ANSI color codes for terminal output
      COLORS = {
        green: "\e[32m",
        red: "\e[31m",
        yellow: "\e[33m",
        blue: "\e[34m",
        cyan: "\e[36m",
        gray: "\e[90m",
        reset: "\e[0m",
        bold: "\e[1m",
      }.freeze

      # Colorize text with ANSI color codes
      # @param text [String] The text to colorize
      # @param color [Symbol] The color name from COLORS
      # @return [String] Colorized text or original if colorization disabled
      def colorize(text, color)
        return text unless @colorize
        return text unless COLORS.key?(color)

        "#{COLORS[color]}#{text}#{COLORS[:reset]}"
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
