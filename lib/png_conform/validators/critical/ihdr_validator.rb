# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Critical
      # Validator for PNG IHDR (Image Header) chunk
      #
      # IHDR is always the first chunk in a PNG file and defines:
      # - Image dimensions (width, height)
      # - Bit depth
      # - Color type
      # - Compression method
      # - Filter method
      # - Interlace method
      #
      # Validation rules from PNG spec:
      # - Must be exactly 13 bytes
      # - Width and height must be non-zero
      # - Bit depth must be valid for color type
      # - Color type must be 0, 2, 3, 4, or 6
      # - Compression method must be 0
      # - Filter method must be 0
      # - Interlace method must be 0 or 1
      class IhdrValidator < BaseValidator
        # Valid color types
        COLOR_TYPES = {
          0 => "grayscale",
          2 => "truecolor",
          3 => "indexed-color",
          4 => "grayscale with alpha",
          6 => "truecolor with alpha",
        }.freeze

        # Valid bit depths for each color type
        VALID_BIT_DEPTHS = {
          0 => [1, 2, 4, 8, 16],       # Grayscale
          2 => [8, 16],                # Truecolor
          3 => [1, 2, 4, 8],           # Indexed-color
          4 => [8, 16],                # Grayscale with alpha
          6 => [8, 16], # Truecolor with alpha
        }.freeze

        # Validate IHDR chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_length(13)

          data = chunk.chunk_data
          width = data[0, 4].unpack1("N")
          height = data[4, 4].unpack1("N")
          bit_depth = data[8].unpack1("C")
          color_type = data[9].unpack1("C")
          compression = data[10].unpack1("C")
          filter = data[11].unpack1("C")
          interlace = data[12].unpack1("C")

          valid = true
          valid &= check_dimensions(width, height)
          valid &= check_color_type(color_type)
          valid &= check_bit_depth(bit_depth, color_type)
          valid &= check_compression(compression)
          valid &= check_filter(filter)
          valid &= check_interlace(interlace)

          if valid
            store_ihdr_info(width, height, bit_depth, color_type,
                            interlace)
          end

          valid
        end

        private

        # Check image dimensions
        def check_dimensions(width, height)
          valid = true

          if width.zero?
            add_error("invalid image width (0)")
            valid = false
          end

          if height.zero?
            add_error("invalid image height (0)")
            valid = false
          end

          if width > 2**31 - 1
            add_warning("image width (#{width}) exceeds maximum " \
                        "recommended value")
          end

          if height > 2**31 - 1
            add_warning("image height (#{height}) exceeds maximum " \
                        "recommended value")
          end

          valid
        end

        # Check color type is valid
        def check_color_type(color_type)
          check_enum(color_type, COLOR_TYPES.keys, "color type")
        end

        # Check bit depth is valid for color type
        def check_bit_depth(bit_depth, color_type)
          return false unless COLOR_TYPES.key?(color_type)

          valid_depths = VALID_BIT_DEPTHS[color_type]
          return true if valid_depths.include?(bit_depth)

          add_error("invalid bit depth (#{bit_depth}) for " \
                    "#{COLOR_TYPES[color_type]} (must be one of " \
                    "#{valid_depths.join(', ')})")
          false
        end

        # Check compression method
        def check_compression(compression)
          if compression != 0
            add_error("invalid compression method (#{compression}, " \
                      "must be 0)")
            return false
          end
          true
        end

        # Check filter method
        def check_filter(filter)
          if filter != 0
            add_error("invalid filter method (#{filter}, must be 0)")
            return false
          end
          true
        end

        # Check interlace method
        def check_interlace(interlace)
          check_enum(interlace, [0, 1], "interlace method")
        end

        # Store IHDR information in context for use by other validators
        def store_ihdr_info(width, height, bit_depth, color_type, interlace)
          context.store(:width, width)
          context.store(:height, height)
          context.store(:bit_depth, bit_depth)
          context.store(:color_type, color_type)
          context.store(:interlace, interlace)
          context.store(:color_type_name, COLOR_TYPES[color_type])
        end
      end
    end
  end
end
