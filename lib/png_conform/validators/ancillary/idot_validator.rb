# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG iDOT (Apple Display Optimization) chunk
      #
      # iDOT is an Apple-specific chunk found in screenshots and images saved
      # from macOS/iOS devices. It contains display optimization data for
      # Retina displays and multi-core decoding performance.
      #
      # iDOT contains 28 bytes (seven 32-bit little-endian integers):
      # - Display scale and density information
      # - Resolution metadata for high-DPI displays
      #
      # Validation rules:
      # - Chunk must be exactly 28 bytes
      # - Only one iDOT chunk allowed
      # - Must appear before IDAT chunk
      class IdotValidator < BaseValidator
        # Expected chunk length (7 x 4-byte integers)
        EXPECTED_LENGTH = 28

        # Validate iDOT chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_uniqueness
          return false unless check_position
          return false unless check_length

          store_idot_info
          true
        end

        private

        # Check that only one iDOT chunk exists
        def check_uniqueness
          if context.retrieve(:has_idot)
            add_error("Multiple iDOT chunks (only one allowed)")
            return false
          end

          true
        end

        # Check that iDOT appears before IDAT
        def check_position
          if context.seen?("IDAT")
            add_error("iDOT chunk after IDAT chunk")
            return false
          end

          true
        end

        # Check chunk length
        def check_length
          actual_length = chunk.chunk_data.length

          unless actual_length == EXPECTED_LENGTH
            add_error("iDOT chunk wrong length (#{actual_length} byte(s), " \
                      "expected #{EXPECTED_LENGTH})")
            return false
          end

          true
        end

        # Store iDOT information in context
        def store_idot_info
          data = chunk.chunk_data

          # Parse the seven 32-bit little-endian integers
          values = data.unpack("V7")

          # Store in context
          context.store(:has_idot, true)
          context.store(:idot_values, values)

          # Add info about the iDOT chunk
          add_info("iDOT: Apple display optimization data (#{values.join(', ')})")
        end
      end
    end
  end
end
