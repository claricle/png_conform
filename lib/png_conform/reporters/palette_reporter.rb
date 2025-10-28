# frozen_string_literal: true

require_relative "base_reporter"

module PngConform
  module Reporters
    # Palette reporter - outputs palette details (-p flag)
    # Matches pngcheck -p output format
    # Prints PLTE, tRNS, hIST, sPLT and PPLT chunk contents
    class PaletteReporter < BaseReporter
      def report(file_analysis)
        # File header (similar to verbose mode)
        write_line("File: #{file_analysis.file_path} (#{file_analysis.file_size} bytes)")

        # Find and output palette-related chunks
        file_analysis.chunks&.each do |chunk|
          case chunk.type
          when "PLTE"
            output_plte_chunk(chunk)
          when "tRNS", "hIST", "sPLT", "PPLT"
            output_palette_chunk(chunk)
          end
        end

        # Standard summary line
        write_line(file_analysis.summary_line)
      end

      private

      def output_plte_chunk(chunk)
        return unless chunk.decoded_data.is_a?(PngConform::Models::PlteData)

        write_line("  PLTE chunk: #{chunk.decoded_data.summary}")
        chunk.decoded_data.detailed_entries.each do |entry_line|
          write_line("    #{entry_line}")
        end
      end

      def output_palette_chunk(chunk)
        write_line("  #{chunk.type} chunk at offset #{chunk.offset_hex}, length #{chunk.length}")
        return unless chunk.decoded_data

        write_line("    #{chunk.decoded_data.summary}")
      end
    end
  end
end
