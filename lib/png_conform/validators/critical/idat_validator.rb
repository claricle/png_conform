# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Critical
      # Validator for PNG IDAT (Image Data) chunk
      #
      # IDAT contains the compressed image data using zlib compression.
      # Multiple IDAT chunks may be present and must be consecutive.
      #
      # Validation rules from PNG spec:
      # - At least one IDAT chunk must be present
      # - All IDAT chunks must be consecutive (no other chunks between them)
      # - Must appear after IHDR chunk
      # - Must appear after PLTE chunk (if present for indexed-color)
      # - CRC must be valid
      # - Combined data forms valid zlib stream (full validation in Phase 8)
      #
      # This validator performs basic structural checks.
      # Full zlib decompression and filter validation is in Phase 8.
      class IdatValidator < BaseValidator
        # Validate IDAT chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_not_empty
          return false unless check_position

          record_idat_chunk
          true
        end

        private

        # Check that IDAT chunk is not empty
        def check_not_empty
          return true unless chunk.chunk_data.empty?

          add_error("IDAT chunk is empty")
          false
        end

        # Check IDAT position relative to other chunks
        def check_position
          valid = true

          # IDAT must appear after IHDR
          unless context.seen?("IHDR")
            add_error("IDAT chunk before IHDR")
            valid = false
          end

          # For indexed-color, IDAT must appear after PLTE
          color_type = context.retrieve(:color_type)
          if color_type == 3 && !context.seen?("PLTE")
            add_error("IDAT chunk before PLTE for indexed-color image")
            valid = false
          end

          valid
        end

        # Record IDAT chunk for sequence validation
        def record_idat_chunk
          context.record_chunk("IDAT", chunk)

          # Track total IDAT size for compression ratio calculation
          total_size = context.retrieve(:total_idat_size) || 0
          context.store(:total_idat_size, total_size + chunk.chunk_data.length)
        end
      end
    end
  end
end
