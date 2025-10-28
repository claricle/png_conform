# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Jng
      # Validates JNG JDAT (JPEG image data) chunks
      #
      # The JDAT chunk contains JPEG-compressed image data. Multiple JDAT chunks
      # may be present in a JNG file and must be concatenated in sequence to
      # form the complete JPEG datastream.
      #
      # Validation rules:
      # - Must appear after JHDR
      # - Contains JPEG compressed data
      # - Multiple JDAT chunks allowed (concatenated in sequence)
      # - Must appear before IEND
      class JdatValidator < BaseValidator
        # Validate JDAT chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc

          valid = true

          # JDAT must appear after JHDR
          unless context.retrieve(:jhdr_present)
            add_error("JDAT must appear after JHDR")
            valid = false
          end

          # JDAT must appear before IEND
          if context.seen?("IEND")
            add_error("JDAT must appear before IEND")
            valid = false
          end

          # Check minimum length (at least 1 byte of JPEG data)
          data = chunk.chunk_data
          if data.empty?
            add_error("JDAT chunk too short (#{data.length} bytes, " \
                      "minimum 1)")
            valid = false
          end

          if valid
            # Store JDAT count for tracking
            jdat_count = context.retrieve(:jdat_count) || 0
            context.store(:jdat_count, jdat_count + 1)

            # Track total JDAT data length
            total_jdat_length = context.retrieve(:jdat_data_length) || 0
            context.store(:jdat_data_length, total_jdat_length + data.length)
          end

          # NOTE: We don't validate JPEG structure here - that would require
          # JPEG parsing which is beyond the scope of JNG chunk validation

          valid
        end
      end
    end
  end
end
