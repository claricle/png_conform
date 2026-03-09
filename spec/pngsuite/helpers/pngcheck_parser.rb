# frozen_string_literal: true

module PngSuite
  module Helpers
    # Parses pngcheck output into semantic information
    class PngcheckParser
      attr_reader :output

      def initialize(output)
        @output = output
      end

      def valid?
        output.start_with?("OK:")
      end

      def corrupted?
        output.include?("CORRUPTED")
      end

      def has_errors?
        output.include?("ERROR:")
      end

      def dimensions
        return nil unless valid?

        return unless output =~ /\((\d+)x(\d+),/

        { width: ::Regexp.last_match(1).to_i,
          height: ::Regexp.last_match(2).to_i }
      end

      def bit_depth
        return nil unless valid?

        return unless output =~ /(\d+)-bit/

        ::Regexp.last_match(1).to_i
      end

      def color_type
        return nil unless valid?

        case output
        when /grayscale\+alpha/
          "grayscale+alpha"
        when /grayscale/
          "grayscale"
        when /RGB\+alpha/, /truecolor\+alpha/
          "RGB+alpha"
        when /RGB/, /truecolor/
          "RGB"
        when /palette/, /indexed/
          "palette"
        end
      end

      def interlaced?
        return false unless valid?

        output.include?("interlaced") && !output.include?("non-interlaced")
      end

      def error_messages
        return [] unless has_errors?

        lines = output.lines
        lines.select { |line| line.start_with?("ERROR:") }
          .map { |line| line.sub(/^ERROR:\s*/, "").strip }
      end

      def to_h
        {
          valid: valid?,
          corrupted: corrupted?,
          has_errors: has_errors?,
          dimensions: dimensions,
          bit_depth: bit_depth,
          color_type: color_type,
          interlaced: interlaced?,
          error_messages: error_messages,
        }
      end
    end
  end
end
