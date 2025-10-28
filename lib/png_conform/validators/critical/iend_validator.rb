# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Critical
      # Validator for PNG IEND (Image Trailer) chunk
      #
      # IEND marks the end of the PNG datastream.
      #
      # Validation rules from PNG spec:
      # - Must be the last chunk in the file
      # - Must be exactly 0 bytes in length
      # - CRC must be valid
      # - Must appear after at least one IDAT chunk
      class IendValidator < BaseValidator
        # Validate IEND chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_empty
          return false unless check_position

          record_iend_chunk
          true
        end

        private

        # Check that IEND chunk is empty
        def check_empty
          return true if chunk.chunk_data.empty?

          add_error("invalid IEND chunk length " \
                    "(#{chunk.chunk_data.length}, should be 0)")
          false
        end

        # Check IEND position relative to other chunks
        def check_position
          valid = true

          # IEND must appear after IHDR
          unless context.seen?("IHDR")
            add_error("IEND chunk before IHDR")
            valid = false
          end

          # IEND must appear after at least one IDAT
          unless context.seen?("IDAT")
            add_error("IEND chunk before IDAT")
            valid = false
          end

          valid
        end

        # Record IEND chunk
        def record_iend_chunk
          context.record_chunk("IEND", chunk)
          context.store(:has_iend, true)
        end
      end
    end
  end
end
