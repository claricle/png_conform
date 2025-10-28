# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG oFFs (Image Offset) chunk
      #
      # oFFs specifies the offset of the image from a reference point:
      # - X position (4 bytes, signed)
      # - Y position (4 bytes, signed)
      # - Unit specifier (1 byte)
      #
      # Validation rules from PNG spec:
      # - Chunk must be exactly 9 bytes
      # - Unit must be 0 (pixels) or 1 (micrometers)
      # - Must appear before IDAT chunk
      # - Only one oFFs chunk allowed
      class OffsValidator < BaseValidator
        # Expected chunk length
        EXPECTED_LENGTH = 9

        # Valid unit specifiers
        UNIT_PIXELS = 0
        UNIT_MICROMETERS = 1
        VALID_UNITS = [UNIT_PIXELS, UNIT_MICROMETERS].freeze

        # Unit names for display
        UNIT_NAMES = {
          UNIT_PIXELS => "pixels",
          UNIT_MICROMETERS => "micrometers",
        }.freeze

        # Validate oFFs chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_uniqueness
          return false unless check_position
          return false unless check_length
          return false unless check_unit

          store_offset_info
          true
        end

        private

        # Check that only one oFFs chunk exists
        def check_uniqueness
          if context.retrieve(:has_offset)
            add_error("Multiple oFFs chunks (only one allowed)")
            return false
          end

          true
        end

        # Check that oFFs appears before IDAT
        def check_position
          if context.seen?("IDAT")
            add_error("oFFs chunk after IDAT chunk")
            return false
          end

          true
        end

        # Check chunk length
        def check_length
          actual_length = chunk.chunk_data.length

          unless actual_length == EXPECTED_LENGTH
            add_error("oFFs chunk wrong length (#{actual_length} bytes, " \
                      "expected #{EXPECTED_LENGTH})")
            return false
          end

          true
        end

        # Check unit specifier
        def check_unit
          data = chunk.chunk_data
          unit = data[8].ord

          unless VALID_UNITS.include?(unit)
            add_error("oFFs invalid unit specifier (#{unit}, " \
                      "must be 0 or 1)")
            return false
          end

          true
        end

        # Store offset information in context
        def store_offset_info
          data = chunk.chunk_data

          # Parse X position (4 bytes, signed big-endian)
          x_bytes = data[0, 4].bytes
          x_pos = (x_bytes[0] << 24) | (x_bytes[1] << 16) |
            (x_bytes[2] << 8) | x_bytes[3]
          # Convert to signed
          x_pos -= (1 << 32) if x_pos >= (1 << 31)

          # Parse Y position (4 bytes, signed big-endian)
          y_bytes = data[4, 4].bytes
          y_pos = (y_bytes[0] << 24) | (y_bytes[1] << 16) |
            (y_bytes[2] << 8) | y_bytes[3]
          # Convert to signed
          y_pos -= (1 << 32) if y_pos >= (1 << 31)

          # Parse unit
          unit = data[8].ord
          unit_name = UNIT_NAMES[unit]

          # Store in context
          context.store(:has_offset, true)
          context.store(:offset_x, x_pos)
          context.store(:offset_y, y_pos)
          context.store(:offset_unit, unit)

          # Add info about the offset
          add_info("oFFs: position (#{x_pos}, #{y_pos}) #{unit_name}")
        end
      end
    end
  end
end
