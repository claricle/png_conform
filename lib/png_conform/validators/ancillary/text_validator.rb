# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG tEXt (Textual Data) chunk
      #
      # tEXt contains textual information as keyword/text pairs:
      # - Keyword (1-79 bytes, Latin-1)
      # - Null separator (1 byte)
      # - Text (0+ bytes, Latin-1)
      #
      # Validation rules from PNG spec:
      # - Keyword must be 1-79 characters
      # - Keyword must contain only Latin-1 printable characters
      # - Keyword must not have leading/trailing spaces
      # - Keyword must not have consecutive spaces
      # - Null separator must be present
      # - Multiple tEXt chunks allowed with different keywords
      class TextValidator < BaseValidator
        # Maximum keyword length
        MAX_KEYWORD_LENGTH = 79

        # Latin-1 printable characters (space to tilde + high ASCII)
        PRINTABLE_LATIN1 = (32..126).to_a + (161..255).to_a

        # Validate tEXt chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_structure
          return false unless check_keyword

          store_text_info
          true
        end

        private

        # Check tEXt chunk structure
        def check_structure
          data = chunk.chunk_data

          # Must contain at least keyword + null
          if data.length < 2
            add_error("tEXt chunk too short (minimum 2 bytes)")
            return false
          end

          # Must contain null separator
          null_pos = data.index("\0")
          unless null_pos
            add_error("tEXt chunk missing null separator")
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
            add_error("tEXt chunk has empty keyword")
            return false
          end

          if keyword.length > MAX_KEYWORD_LENGTH
            add_error("tEXt keyword too long (#{keyword.length}, " \
                      "max #{MAX_KEYWORD_LENGTH})")
            return false
          end

          # Check for Latin-1 printable characters
          keyword.bytes.each do |byte|
            next if PRINTABLE_LATIN1.include?(byte)

            add_error("tEXt keyword contains non-printable character " \
                      "(0x#{byte.to_s(16)})")
            return false
          end

          # Check for leading/trailing spaces
          if keyword.start_with?(" ")
            add_error("tEXt keyword has leading space")
            return false
          end

          if keyword.end_with?(" ")
            add_error("tEXt keyword has trailing space")
            return false
          end

          # Check for consecutive spaces
          if keyword.include?("  ")
            add_error("tEXt keyword has consecutive spaces")
            return false
          end

          true
        end

        # Store text information in context
        def store_text_info
          data = chunk.chunk_data
          null_pos = data.index("\0")
          keyword = data[0, null_pos]
          text = data[(null_pos + 1)..] || ""

          # Store in context (allow multiple text chunks)
          texts = context.retrieve(:text_chunks) || []
          texts << { keyword: keyword, text: text, compressed: false }
          context.store(:text_chunks, texts)

          # Add info about the text chunk
          text_preview = text.length > 40 ? "#{text[0, 40]}..." : text
          add_info("tEXt: #{keyword} = \"#{text_preview}\"")
        end
      end
    end
  end
end
