# frozen_string_literal: true

require_relative "../base_validator"
require "zlib"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG zTXt (Compressed Textual Data) chunk
      #
      # zTXt contains compressed textual information as keyword/text pairs:
      # - Keyword (1-79 bytes, Latin-1)
      # - Null separator (1 byte)
      # - Compression method (1 byte, must be 0)
      # - Compressed text (0+ bytes, deflate compressed)
      #
      # Validation rules from PNG spec:
      # - Keyword must be 1-79 characters
      # - Keyword must contain only Latin-1 printable characters
      # - Keyword must not have leading/trailing spaces
      # - Keyword must not have consecutive spaces
      # - Compression method must be 0 (deflate)
      # - Text must be successfully decompressible
      # - Multiple zTXt chunks allowed with different keywords
      class ZtxtValidator < BaseValidator
        # Maximum keyword length
        MAX_KEYWORD_LENGTH = 79

        # Latin-1 printable characters (space to tilde + high ASCII)
        PRINTABLE_LATIN1 = (32..126).to_a + (161..255).to_a

        # Valid compression method
        COMPRESSION_DEFLATE = 0

        # Validate zTXt chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_structure
          return false unless check_keyword
          return false unless check_compression_method
          return false unless check_decompression

          store_text_info
          true
        end

        private

        # Check zTXt chunk structure
        def check_structure
          data = chunk.chunk_data

          # Must contain at least keyword + null + compression method
          if data.length < 3
            add_error("zTXt chunk too short (minimum 3 bytes)")
            return false
          end

          # Must contain null separator
          null_pos = data.index("\0")
          unless null_pos
            add_error("zTXt chunk missing null separator")
            return false
          end

          true
        end

        # Check keyword validity
        def check_keyword
          data = chunk.chunk_data
          null_pos = data.index("\0")
          keyword = data[0, null_pos]

          # Check keyword length
          if keyword.empty?
            add_error("zTXt chunk has empty keyword")
            return false
          end

          if keyword.length > MAX_KEYWORD_LENGTH
            add_error("zTXt keyword too long (#{keyword.length}, " \
                      "max #{MAX_KEYWORD_LENGTH})")
            return false
          end

          # Check for Latin-1 printable characters
          keyword.bytes.each do |byte|
            next if PRINTABLE_LATIN1.include?(byte)

            add_error("zTXt keyword contains non-printable character " \
                      "(0x#{byte.to_s(16)})")
            return false
          end

          # Check for leading/trailing spaces
          if keyword.start_with?(" ")
            add_error("zTXt keyword has leading space")
            return false
          end

          if keyword.end_with?(" ")
            add_error("zTXt keyword has trailing space")
            return false
          end

          # Check for consecutive spaces
          if keyword.include?("  ")
            add_error("zTXt keyword has consecutive spaces")
            return false
          end

          true
        end

        # Check compression method
        def check_compression_method
          data = chunk.chunk_data
          null_pos = data.index("\0")
          compression_method = data[null_pos + 1].ord

          unless compression_method == COMPRESSION_DEFLATE
            add_error("zTXt invalid compression method " \
                      "(#{compression_method}, must be 0)")
            return false
          end

          true
        end

        # Check that compressed data can be decompressed
        def check_decompression
          data = chunk.chunk_data
          null_pos = data.index("\0")
          compressed_data = data[(null_pos + 2)..] || ""

          # Try to decompress
          begin
            Zlib::Inflate.inflate(compressed_data)
          rescue Zlib::Error => e
            add_error("zTXt decompression failed: #{e.message}")
            return false
          end

          true
        end

        # Store text information in context
        def store_text_info
          data = chunk.chunk_data
          null_pos = data.index("\0")
          keyword = data[0, null_pos]
          compressed_data = data[(null_pos + 2)..] || ""

          # Decompress text
          text = Zlib::Inflate.inflate(compressed_data)

          # Store in context (allow multiple text chunks)
          texts = context.retrieve(:text_chunks) || []
          texts << { keyword: keyword, text: text, compressed: true }
          context.store(:text_chunks, texts)

          # Add info about the text chunk
          text_preview = text.length > 40 ? "#{text[0, 40]}..." : text
          add_info("zTXt: #{keyword} = \"#{text_preview}\" " \
                   "(compressed from #{compressed_data.length} bytes)")
        end
      end
    end
  end
end
