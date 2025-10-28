# frozen_string_literal: true

require_relative "../base_validator"
require "zlib"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG iCCP (Embedded ICC Profile) chunk
      #
      # iCCP contains an ICC color profile:
      # - Profile name (1-79 bytes, Latin-1)
      # - Null separator (1 byte)
      # - Compression method (1 byte, must be 0)
      # - Compressed profile (deflate compressed ICC profile)
      #
      # Validation rules from PNG spec:
      # - Profile name must be 1-79 characters, Latin-1 printable
      # - Profile name must not have leading/trailing/consecutive spaces
      # - Compression method must be 0 (deflate)
      # - Profile must be successfully decompressible
      # - Must appear before PLTE and IDAT chunks
      # - Only one iCCP chunk allowed
      # - Should not appear with sRGB chunk (warns if both present)
      class IccpValidator < BaseValidator
        # Maximum profile name length
        MAX_PROFILE_NAME_LENGTH = 79

        # Latin-1 printable characters (space to tilde + high ASCII)
        PRINTABLE_LATIN1 = (32..126).to_a + (161..255).to_a

        # Valid compression method
        COMPRESSION_DEFLATE = 0

        # ICC profile signature (first 4 bytes of decompressed data)
        ICC_SIGNATURE_OFFSET = 36
        ICC_SIGNATURE = "acsp"

        # Validate iCCP chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_uniqueness
          return false unless check_position
          return false unless check_structure
          return false unless check_profile_name
          return false unless check_compression_method
          return false unless check_decompression

          check_srgb_conflict

          store_profile_info
          true
        end

        private

        # Check that only one iCCP chunk exists
        def check_uniqueness
          if context.retrieve(:has_icc_profile)
            add_error("Multiple iCCP chunks (only one allowed)")
            return false
          end

          true
        end

        # Check that iCCP appears before PLTE and IDAT
        def check_position
          # Must come before PLTE
          if context.seen?("PLTE")
            add_error("iCCP chunk after PLTE chunk")
            return false
          end

          # Must come before IDAT
          if context.seen?("IDAT")
            add_error("iCCP chunk after IDAT chunk")
            return false
          end

          true
        end

        # Check iCCP chunk structure
        def check_structure
          data = chunk.chunk_data

          # Must contain at least name + null + compression method
          if data.length < 3
            add_error("iCCP chunk too short (minimum 3 bytes)")
            return false
          end

          # Must contain null separator
          null_pos = data.index("\0")
          unless null_pos
            add_error("iCCP chunk missing null separator")
            return false
          end

          true
        end

        # Check profile name validity
        def check_profile_name
          data = chunk.chunk_data
          null_pos = data.index("\0")
          profile_name = data[0, null_pos]

          # Check profile name length
          if profile_name.empty?
            add_error("iCCP chunk has empty profile name")
            return false
          end

          if profile_name.length > MAX_PROFILE_NAME_LENGTH
            add_error("iCCP profile name too long (#{profile_name.length}, " \
                      "max #{MAX_PROFILE_NAME_LENGTH})")
            return false
          end

          # Check for Latin-1 printable characters
          profile_name.bytes.each do |byte|
            next if PRINTABLE_LATIN1.include?(byte)

            add_error("iCCP profile name contains non-printable " \
                      "character (0x#{byte.to_s(16)})")
            return false
          end

          # Check for leading/trailing spaces
          if profile_name.start_with?(" ")
            add_error("iCCP profile name has leading space")
            return false
          end

          if profile_name.end_with?(" ")
            add_error("iCCP profile name has trailing space")
            return false
          end

          # Check for consecutive spaces
          if profile_name.include?("  ")
            add_error("iCCP profile name has consecutive spaces")
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
            add_error("iCCP invalid compression method " \
                      "(#{compression_method}, must be 0)")
            return false
          end

          true
        end

        # Check that profile data can be decompressed and validate ICC
        # signature
        def check_decompression
          data = chunk.chunk_data
          null_pos = data.index("\0")
          compressed_data = data[(null_pos + 2)..] || ""

          # Try to decompress
          begin
            decompressed = Zlib::Inflate.inflate(compressed_data)

            # Check minimum ICC profile size (128 bytes header)
            if decompressed.length < 128
              add_error("iCCP decompressed profile too short " \
                        "(#{decompressed.length} bytes, minimum 128)")
              return false
            end

            # Verify ICC signature if enough data
            if decompressed.length >= ICC_SIGNATURE_OFFSET + 4
              signature = decompressed[ICC_SIGNATURE_OFFSET, 4]
              unless signature == ICC_SIGNATURE
                add_warning("iCCP profile signature mismatch " \
                            "(expected 'acsp', got '#{signature}')")
              end
            end
          rescue Zlib::Error => e
            add_error("iCCP decompression failed: #{e.message}")
            return false
          end

          true
        end

        # Check for conflict with sRGB chunk
        def check_srgb_conflict
          if context.retrieve(:uses_srgb)
            add_warning("iCCP chunk present with sRGB chunk " \
                        "(iCCP takes precedence)")
          end

          true
        end

        # Store ICC profile information in context
        def store_profile_info
          data = chunk.chunk_data
          null_pos = data.index("\0")
          profile_name = data[0, null_pos]
          compressed_data = data[(null_pos + 2)..] || ""

          # Decompress profile
          decompressed = Zlib::Inflate.inflate(compressed_data)

          # Store in context
          context.store(:has_icc_profile, true)
          context.store(:icc_profile_name, profile_name)
          context.store(:icc_profile_size, decompressed.length)

          # Add info about the ICC profile
          compression_ratio = if compressed_data.length.positive?
                                (decompressed.length.to_f /
                                 compressed_data.length).round(2)
                              else
                                0
                              end

          add_info("iCCP: \"#{profile_name}\" " \
                   "(#{decompressed.length} bytes, " \
                   "compressed from #{compressed_data.length} bytes, " \
                   "ratio #{compression_ratio}:1)")
        end
      end
    end
  end
end
