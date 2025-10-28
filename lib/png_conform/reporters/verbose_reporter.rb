# frozen_string_literal: true

require_relative "base_reporter"
require_relative "visual_elements"

module PngConform
  module Reporters
    # Verbose reporter - outputs detailed chunk information with colors and emojis
    # Matches pngcheck -v output format with visual enhancements
    class VerboseReporter < BaseReporter
      include VisualElements

      def initialize(output = $stdout, colorize: true)
        super(output)
        @colorize = colorize
      end

      def report(validation_result)
        write_line(format_file_header(validation_result))
        write_line("")

        validation_result.chunks.each do |chunk|
          write_line(format_chunk(chunk))
        end

        if validation_result.errors.any?
          write_line("")
          write_line(colorize("VALIDATION ERRORS:", :red))
          validation_result.errors.each do |error|
            write_line(format_error(error))
          end
        end

        write_line("")
        write_line(format_summary(validation_result))
      end

      private

      def format_file_header(result)
        emoji_file = emoji(:file)
        filename = colorize(result.filename, :bold)
        "#{emoji_file} #{filename} (#{result.file_size} bytes)"
      end

      def format_chunk(chunk)
        emoji_chunk = emoji(:chunk)

        status = if chunk.valid_crc
                   colorize(emoji(:valid_crc), :green)
                 else
                   colorize(emoji(:invalid_crc), :red)
                 end

        chunk_type = colorize(chunk.type, :cyan)
        offset = colorize(chunk.offset_hex, :gray)

        "  #{status} #{emoji_chunk} #{chunk_type} at #{offset} (#{chunk.length} bytes)"
      end

      def format_error(error)
        severity_emoji = emoji(error.severity.to_sym)
        severity_text = colorize(error.severity.upcase,
                                 color_for_severity(error.severity))
        "  #{severity_emoji} #{severity_text}: #{error.message}"
      end

      def format_summary(result)
        status = if result.valid?
                   colorize("#{emoji(:valid_crc)} No errors detected", :green)
                 else
                   colorize("#{emoji(:invalid_crc)} ERRORS DETECTED", :red)
                 end

        compression = if result.compression_ratio
                        " #{emoji(:compression)} #{colorize(
                          format('%.1f%%', result.compression_ratio), :cyan
                        )}"
                      else
                        ""
                      end

        "#{status} in #{result.filename} (#{result.chunk_count} chunks#{compression})"
      end
    end
  end
end
