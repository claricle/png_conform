# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG sCAL (Physical Scale) chunk
      #
      # sCAL specifies the physical scale of the image:
      # - Unit specifier (1 byte)
      # - Pixel width (null-terminated ASCII floating point)
      # - Pixel height (null-terminated ASCII floating point)
      #
      # Validation rules from PNG spec:
      # - Unit must be 1 (meters) or 2 (radians)
      # - Width and height must be valid ASCII floating point numbers
      # - Width and height must be positive
      # - Must appear before IDAT chunk
      # - Only one sCAL chunk allowed
      class ScalValidator < BaseValidator
        # Valid unit specifiers
        UNIT_METER = 1
        UNIT_RADIAN = 2
        VALID_UNITS = [UNIT_METER, UNIT_RADIAN].freeze

        # Unit names for display
        UNIT_NAMES = {
          UNIT_METER => "meter",
          UNIT_RADIAN => "radian",
        }.freeze

        # ASCII floating point regex (simple form)
        FLOAT_REGEX = /\A[+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\z/

        # Validate sCAL chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_uniqueness
          return false unless check_position
          return false unless check_structure
          return false unless check_unit
          return false unless check_dimensions

          store_scale_info
          true
        end

        private

        # Check that only one sCAL chunk exists
        def check_uniqueness
          if context.seen?("sCAL") || context.retrieve(:has_scale)
            add_error("duplicate sCAL chunk (only one allowed)")
            return false
          end

          true
        end

        # Check that sCAL appears before IDAT
        def check_position
          if context.seen?("IDAT")
            add_error("sCAL chunk after IDAT chunk")
            return false
          end

          true
        end

        # Check sCAL chunk structure
        def check_structure
          data = chunk.chunk_data

          # Must contain at least unit + width + null + height + null
          if data.length < 5
            add_error("sCAL chunk too short (minimum 5 bytes)")
            return false
          end

          # Must contain two null separators
          nulls = data.bytes.each_index.select { |i| data[i] == "\0" }
          if nulls.length < 2
            add_error("sCAL chunk missing null separators " \
                      "(found #{nulls.length}, need 2)")
            return false
          end

          true
        end

        # Check unit specifier
        def check_unit
          data = chunk.chunk_data
          unit = data[0].ord

          unless VALID_UNITS.include?(unit)
            add_error("sCAL invalid unit specifier (#{unit}, " \
                      "must be 1 or 2)")
            return false
          end

          true
        end

        # Check dimension strings
        def check_dimensions
          data = chunk.chunk_data
          first_null = data.index("\0", 1)
          second_null = data.index("\0", first_null + 1)

          width_str = data[1, first_null - 1]
          height_str = data[(first_null + 1), second_null - first_null - 1]

          # Check width
          unless valid_float_string?(width_str)
            add_error("sCAL invalid width format: '#{width_str}'")
            return false
          end

          width = width_str.to_f
          unless width.positive?
            add_error("sCAL width must be positive (got #{width})")
            return false
          end

          # Check height
          unless valid_float_string?(height_str)
            add_error("sCAL invalid height format: '#{height_str}'")
            return false
          end

          height = height_str.to_f
          unless height.positive?
            add_error("sCAL height must be positive (got #{height})")
            return false
          end

          true
        end

        # Validate floating point string format
        def valid_float_string?(str)
          return false if str.empty?
          return false unless str.match?(FLOAT_REGEX)

          # Additional check: must be finite
          value = str.to_f
          value.finite?
        end

        # Store scale information in context
        def store_scale_info
          data = chunk.chunk_data
          unit = data[0].ord
          first_null = data.index("\0", 1)
          second_null = data.index("\0", first_null + 1)

          width_str = data[1, first_null - 1]
          height_str = data[(first_null + 1), second_null - first_null - 1]

          width = width_str.to_f
          height = height_str.to_f
          unit_name = UNIT_NAMES[unit]

          # Store in context
          context.store(:has_scale, true)
          context.store(:scale_width, width)
          context.store(:scale_height, height)
          context.store(:scale_unit, unit)

          # Add info about the scale
          add_info("sCAL: #{width} x #{height} #{unit_name}s per pixel")
        end
      end
    end
  end
end
