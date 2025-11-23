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
      # Structure (28 bytes - seven 32-bit little-endian integers):
      # - Display scale factor (4 bytes)
      # - Pixel format information (4 bytes)
      # - Color space information (4 bytes)
      # - Backing scale factor (4 bytes)
      # - Flags (4 bytes)
      # - Reserved field 1 (4 bytes)
      # - Reserved field 2 (4 bytes)
      #
      # Validation rules:
      # - Chunk must be exactly 28 bytes
      # - Only one iDOT chunk allowed
      # - Must appear before IDAT chunk
      #
      # References:
      # - Apple's proprietary display optimization format
      # - Used in macOS/iOS screenshot PNG files
      class IdotValidator < BaseValidator
        # Expected chunk length (7 x 4-byte integers)
        EXPECTED_LENGTH = 28

        # Validate iDOT chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_length(EXPECTED_LENGTH)
          return false unless check_uniqueness
          return false unless check_position

          decode_and_store_data
          true
        end

        private

        # Check that only one iDOT chunk exists
        def check_uniqueness
          if context.seen?("iDOT")
            add_error("duplicate iDOT chunk (only one allowed)")
            return false
          end

          true
        end

        # Check that iDOT appears before IDAT
        def check_position
          if context.seen?("IDAT")
            add_error("iDOT chunk after IDAT (must be before)")
            return false
          end

          true
        end

        # Decode iDOT data and store in context
        def decode_and_store_data
          values = chunk.chunk_data.unpack("V7")

          # Create IdotData model
          idot_data = create_idot_data(values)

          # Store in context for later use
          context.store(:idot_data, idot_data)

          # Add info message with decoded data
          add_info("iDOT: Apple display optimization (#{idot_data.detailed_info})")
        end

        # Create IdotData model from parsed values
        #
        # @param values [Array<Integer>] Seven 32-bit integers
        # @return [Models::IdotData] The decoded data model
        def create_idot_data(values)
          Models::IdotData.new(
            display_scale: values[0],
            pixel_format: values[1],
            color_space: values[2],
            backing_scale_factor: values[3],
            flags: values[4],
            reserved1: values[5],
            reserved2: values[6],
          )
        end
      end
    end
  end
end
