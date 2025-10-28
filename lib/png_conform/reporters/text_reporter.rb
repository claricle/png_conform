# frozen_string_literal: true

require_relative "base_reporter"

module PngConform
  module Reporters
    # Text reporter - extracts and displays text chunk contents (-t flag)
    # Matches pngcheck -t output format
    # Prints tEXt, zTXt, iTXt chunk contents
    class TextReporter < BaseReporter
      attr_reader :escape_mode

      # @param output [IO] Output stream
      # @param escape_mode [Symbol] :seven_bit for -7 flag, :none for -t flag
      def initialize(output = $stdout, escape_mode: :none)
        super(output)
        @escape_mode = escape_mode
      end

      def report(file_analysis)
        has_text_chunks = false

        file_analysis.chunks&.each do |chunk|
          next unless text_chunk?(chunk.type)

          has_text_chunks = true
          output_text_chunk(chunk)
        end

        # If no text chunks found, output standard summary
        write_line(file_analysis.summary_line) unless has_text_chunks
      end

      private

      def text_chunk?(type)
        %w[tEXt zTXt iTXt].include?(type)
      end

      def output_text_chunk(chunk)
        write_line("#{chunk.type} chunk:")
        if chunk.decoded_data.respond_to?(:keyword) && chunk.decoded_data.respond_to?(:text)
          text = format_text(chunk.decoded_data.text)
          write_line("  #{chunk.decoded_data.keyword}: #{text}")
        else
          write_line("  <unable to decode>")
        end
      end

      def format_text(text)
        case escape_mode
        when :seven_bit
          escape_non_ascii(text)
        else
          text
        end
      end

      def escape_non_ascii(text)
        text.chars.map do |char|
          char.ord >= 128 ? format("\\x%02x", char.ord) : char
        end.join
      end
    end
  end
end
