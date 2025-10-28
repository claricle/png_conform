# frozen_string_literal: true

require_relative "verbose_reporter"

module PngConform
  module Reporters
    # Very verbose reporter - adds row filter information (-vv flag)
    # Matches pngcheck -vv output format
    class VeryVerboseReporter < VerboseReporter
      def report(file_analysis)
        # File header
        write_line(file_analysis.file_header)

        # Chunk details with filter information
        file_analysis.chunks&.each do |chunk|
          write_line("  #{chunk.summary}")
          next unless chunk.decoded_data

          write_line("    #{chunk.decoded_data.summary}")

          # Add filter summary for IDAT chunks
          if chunk.decoded_data.respond_to?(:filter_summary)
            filter_info = chunk.decoded_data.filter_summary
            write_line("    #{filter_info}") if filter_info
          end
        end

        # Validation summary
        write_line(file_analysis.validation_summary)
      end
    end
  end
end
