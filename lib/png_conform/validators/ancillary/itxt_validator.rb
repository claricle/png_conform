# frozen_string_literal: true

require_relative "../base_validator"
require "zlib"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG iTXt (International Textual Data) chunk
      #
      # iTXt contains international textual information with UTF-8 encoding:
      # - Keyword (1-79 bytes, Latin-1)
      # - Null separator (1 byte)
      # - Compression flag (1 byte, 0=uncompressed, 1=compressed)
      # - Compression method (1 byte, must be 0 if compressed)
      # - Language tag (0+ bytes, ASCII)
      # - Null separator (1 byte)
      # - Translated keyword (0+ bytes, UTF-8)
      # - Null separator (1 byte)
      # - Text (0+ bytes, UTF-8, possibly compressed)
      #
      # Validation rules from PNG spec:
      # - Keyword must be 1-79 characters, Latin-1 printable
      # - Keyword must not have leading/trailing/consecutive spaces
      # - Compression flag must be 0 or 1
      # - Compression method must be 0 if compressed
      # - Language tag must be ASCII (RFC 3066 format)
      # - Translated keyword and text must be valid UTF-8
      # - Multiple iTXt chunks allowed with different keywords
      class ItxtValidator < BaseValidator
        # Maximum keyword length
        MAX_KEYWORD_LENGTH = 79

        # Latin-1 printable characters (space to tilde + high ASCII)
        PRINTABLE_LATIN1 = (32..126).to_a + (161..255).to_a

        # Valid compression flag values
        UNCOMPRESSED = 0
        COMPRESSED = 1

        # Valid compression method
        COMPRESSION_DEFLATE = 0

        # Validate iTXt chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_structure
          return false unless check_keyword
          return false unless check_compression_flags
          return false unless check_language_tag
          return false unless check_utf8_fields

          return false if compressed? && compressed? && !check_decompression

          store_text_info
          true
        end

        private

        # Check iTXt chunk structure
        def check_structure
          data = chunk.chunk_data

          # Must contain at least keyword + 3 nulls + flags
          if data.length < 5
            add_error("iTXt chunk too short (minimum 5 bytes)")
            return false
          end

          # Must contain three null separators
          nulls = data.bytes.each_index.select { |i| data[i] == "\0" }
          if nulls.length < 3
            add_error("iTXt chunk missing null separators " \
                      "(found #{nulls.length}, need 3)")
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
            add_error("iTXt chunk has empty keyword")
            return false
          end

          if keyword.length > MAX_KEYWORD_LENGTH
            add_error("iTXt keyword too long (#{keyword.length}, " \
                      "max #{MAX_KEYWORD_LENGTH})")
            return false
          end

          # Check for Latin-1 printable characters
          keyword.bytes.each do |byte|
            next if PRINTABLE_LATIN1.include?(byte)

            add_error("iTXt keyword contains non-printable character " \
                      "(0x#{byte.to_s(16)})")
            return false
          end

          # Check for leading/trailing spaces
          if keyword.start_with?(" ")
            add_error("iTXt keyword has leading space")
            return false
          end

          if keyword.end_with?(" ")
            add_error("iTXt keyword has trailing space")
            return false
          end

          # Check for consecutive spaces
          if keyword.include?("  ")
            add_error("iTXt keyword has consecutive spaces")
            return false
          end

          true
        end

        # Check compression flag and method
        def check_compression_flags
          data = chunk.chunk_data
          null_pos = data.index("\0")
          compression_flag = data[null_pos + 1].ord
          compression_method = data[null_pos + 2].ord

          unless [UNCOMPRESSED, COMPRESSED].include?(compression_flag)
            add_error("iTXt invalid compression flag " \
                      "(#{compression_flag}, must be 0 or 1)")
            return false
          end

          if compression_flag == COMPRESSED &&
              compression_method != COMPRESSION_DEFLATE
            add_error("iTXt invalid compression method " \
                      "(#{compression_method}, must be 0 when compressed)")
            return false
          end

          true
        end

        # Check language tag (should be ASCII, RFC 3066 format)
        def check_language_tag
          data = chunk.chunk_data
          first_null = data.index("\0")
          second_null = data.index("\0", first_null + 3)
          lang_tag = data[(first_null + 3)...second_null]

          # Language tag can be empty
          return true if lang_tag.empty?

          # Must be ASCII (0-127)
          lang_tag.bytes.each do |byte|
            next unless byte > 127

            add_error("iTXt language tag contains non-ASCII character " \
                      "(0x#{byte.to_s(16)})")
            return false
          end

          true
        end

        # Check UTF-8 validity of translated keyword and text
        def check_utf8_fields
          data = chunk.chunk_data
          first_null = data.index("\0")
          second_null = data.index("\0", first_null + 3)
          third_null = data.index("\0", second_null + 1)

          # Translated keyword
          translated_keyword = data[(second_null + 1)...third_null]
          unless valid_utf8?(translated_keyword)
            add_error("iTXt translated keyword is not valid UTF-8")
            return false
          end

          # Text field (may be compressed)
          text_data = data[(third_null + 1)..] || ""
          if !compressed? && !valid_utf8?(text_data)
            add_error("iTXt text is not valid UTF-8")
            return false
          end

          true
        end

        # Check that compressed data can be decompressed and is valid UTF-8
        def check_decompression
          data = chunk.chunk_data
          first_null = data.index("\0")
          third_null = data.index("\0", data.index("\0", first_null + 3) + 1)
          compressed_data = data[(third_null + 1)..] || ""

          # Try to decompress
          begin
            decompressed = Zlib::Inflate.inflate(compressed_data)
            unless valid_utf8?(decompressed)
              add_error("iTXt decompressed text is not valid UTF-8")
              return false
            end
          rescue Zlib::Error => e
            add_error("iTXt decompression failed: #{e.message}")
            return false
          end

          true
        end

        # Check if compression is enabled
        def compressed?
          data = chunk.chunk_data
          null_pos = data.index("\0")
          data[null_pos + 1].ord == COMPRESSED
        end

        # Validate UTF-8 encoding
        def valid_utf8?(str)
          str.force_encoding("UTF-8").valid_encoding?
        end

        # Store text information in context
        def store_text_info
          data = chunk.chunk_data
          first_null = data.index("\0")
          second_null = data.index("\0", first_null + 3)
          third_null = data.index("\0", second_null + 1)

          keyword = data[0, first_null]
          lang_tag = data[(first_null + 3)...second_null]
          translated_keyword = data[(second_null + 1)...third_null]
          text_data = data[(third_null + 1)..] || ""

          # Decompress if needed
          if compressed?
            text = Zlib::Inflate.inflate(text_data)
            comp_info = " (compressed from #{text_data.length} bytes)"
          else
            text = text_data
            comp_info = ""
          end

          # Force UTF-8 encoding
          text.force_encoding("UTF-8")
          translated_keyword.force_encoding("UTF-8")

          # Store in context (allow multiple text chunks)
          texts = context.retrieve(:text_chunks) || []
          texts << {
            keyword: keyword,
            text: text,
            compressed: compressed?,
            language: lang_tag.empty? ? nil : lang_tag,
            translated_keyword: translated_keyword.empty? ? nil : translated_keyword,
          }
          context.store(:text_chunks, texts)

          # Add info about the text chunk
          text_preview = text.length > 40 ? "#{text[0, 40]}..." : text
          lang_info = lang_tag.empty? ? "" : " [#{lang_tag}]"
          trans_info = translated_keyword.empty? ? "" : " (#{translated_keyword})"
          add_info("iTXt: #{keyword}#{lang_info}#{trans_info} = " \
                   "\"#{text_preview}\"#{comp_info}")
        end
      end
    end
  end
end
