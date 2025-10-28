# frozen_string_literal: true

require_relative "base_reporter"
require_relative "visual_elements"

module PngConform
  module Reporters
    # Summary reporter - outputs one-line summary per file with colors and emojis
    # Default reporter matching pngcheck output format
    # Example: "✅ OK: file.png (PNG, 164 bytes, 4 chunks 🗜️ -28.1%)"
    class SummaryReporter < BaseReporter
      include VisualElements

      def initialize(output = $stdout, colorize: true)
        super(output)
        @colorize = colorize
      end

      def report(validation_result)
        if validation_result.valid?
          write_line(format_success(validation_result))
        else
          write_line(format_error(validation_result))
        end
      end

      private

      def format_success(result)
        emoji_check = emoji(:success)
        status = colorize("OK", :green)

        parts = ["#{emoji_check} #{status}: #{result.filename}"]
        parts << "(#{result.file_type}"
        parts << "#{result.file_size} bytes"
        parts << "#{result.chunk_count} chunks"

        if result.compression_ratio
          compression = "#{emoji(:compression)} #{colorize(
            format('%.1f%%', result.compression_ratio), :cyan
          )}"
          parts << compression
        end

        "#{parts.join(', ')})"
      end

      def format_error(result)
        emoji_err = emoji(:error)
        status = colorize("ERROR", :red)

        lines = ["#{emoji_err} #{status}: #{result.filename}"]

        result.errors.each do |error|
          severity_emoji = emoji(error.severity.to_sym)
          severity_text = colorize(error.severity.upcase,
                                   color_for_severity(error.severity))
          lines << "  #{severity_emoji} #{severity_text}: #{error.message}"
        end

        lines.join("\n")
      end
    end
  end
end
