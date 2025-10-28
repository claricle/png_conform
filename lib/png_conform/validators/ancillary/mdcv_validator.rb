# frozen_string_literal: true

module PngConform
  module Validators
    module Ancillary
      # Validator for mDCv (Mastering Display Color Volume) chunk
      #
      # The mDCv chunk specifies the color volume of the mastering display
      # used for content creation. Introduced in PNG 3rd edition for HDR support.
      #
      # Structure:
      # - Display primaries (12 bytes): 6 x uint16 (x,y for R,G,B)
      #   Each coordinate is in 0.00002 units (range 0-50000 = 0.0-1.0)
      # - White point (4 bytes): 2 x uint16 (x,y)
      #   Each coordinate is in 0.00002 units
      # - Maximum luminance (4 bytes): uint32
      #   In 0.0001 cd/m² units
      # - Minimum luminance (4 bytes): uint32
      #   In 0.0001 cd/m² units
      #
      # Total: 24 bytes
      #
      # Constraints:
      # - Must contain exactly 24 bytes
      # - Must appear before PLTE and IDAT
      # - At most one mDCv chunk allowed
      # - Coordinates must be in range 0-50000 (0.0-1.0 in CIE 1931)
      # - Maximum luminance must be > minimum luminance
      #
      class MdcvValidator < BaseValidator
        CHUNK_TYPE = "mDCV"

        # Maximum coordinate value (0.00002 * 50000 = 1.0)
        MAX_COORDINATE = 50_000

        # Coordinate scale factor
        COORDINATE_SCALE = 0.00002

        # Luminance scale factor (cd/m²)
        LUMINANCE_SCALE = 0.0001

        def validate
          check_chunk_length
          check_uniqueness
          check_position
          validate_fields if chunk.chunk_data.bytesize == 24
        end

        private

        def check_chunk_length
          return if check_length(24)

          add_error("invalid chunk length: #{chunk.chunk_data.bytesize} bytes")
        end

        def check_uniqueness
          return unless context.seen?(CHUNK_TYPE)

          add_error("duplicate mDCV chunk (only one allowed)")
        end

        def check_position
          add_error("mDCv must appear before PLTE") if context.seen?("PLTE")

          return unless context.seen?("IDAT")

          add_error("mDCv must appear before IDAT")
        end

        def validate_fields
          data = chunk.data

          # Parse all uint16 and uint32 values
          red_x = read_uint16(data, 0)
          red_y = read_uint16(data, 2)
          green_x = read_uint16(data, 4)
          green_y = read_uint16(data, 6)
          blue_x = read_uint16(data, 8)
          blue_y = read_uint16(data, 10)
          white_x = read_uint16(data, 12)
          white_y = read_uint16(data, 14)
          max_luminance = read_uint32(data, 16)
          min_luminance = read_uint32(data, 20)

          # Validate display primaries
          validate_primary("red", red_x, red_y)
          validate_primary("green", green_x, green_y)
          validate_primary("blue", blue_x, blue_y)

          # Validate white point
          validate_white_point(white_x, white_y)

          # Validate luminance values
          validate_luminance(max_luminance, min_luminance)

          # Add informational messages about decoded values
          add_display_info(
            red_x, red_y, green_x, green_y, blue_x, blue_y,
            white_x, white_y, max_luminance, min_luminance
          )
        end

        def validate_primary(color, x_value, y_value)
          validate_coordinate("#{color} primary x", x_value)
          validate_coordinate("#{color} primary y", y_value)

          # Check that x + y <= 1.0 (sum <= 50000)
          return unless x_value + y_value > MAX_COORDINATE

          add_warning(
            "#{color} primary coordinates sum > 1.0 " \
            "(x=#{format_coordinate(x_value)}, " \
            "y=#{format_coordinate(y_value)})",
          )
        end

        def validate_white_point(x_value, y_value)
          validate_coordinate("white point x", x_value)
          validate_coordinate("white point y", y_value)

          # Check that x + y <= 1.0
          return unless x_value + y_value > MAX_COORDINATE

          add_warning(
            "white point coordinates sum > 1.0 " \
            "(x=#{format_coordinate(x_value)}, " \
            "y=#{format_coordinate(y_value)})",
          )
        end

        def validate_coordinate(name, value)
          return if check_range(value, 0, MAX_COORDINATE, name)

          add_error(
            "#{name} out of range: #{value} " \
            "(must be 0-#{MAX_COORDINATE})",
          )
        end

        def validate_luminance(max_lum, min_lum)
          # Maximum luminance must be greater than minimum
          if max_lum <= min_lum
            add_error(
              "maximum luminance (#{format_luminance(max_lum)}) must be > " \
              "minimum luminance (#{format_luminance(min_lum)})",
            )
          end

          # Check for reasonable luminance ranges
          add_warning("maximum luminance is 0 cd/m²") if max_lum.zero?

          return unless max_lum > 100_000_000 # 10,000 cd/m²

          add_warning(
            "maximum luminance very high: #{format_luminance(max_lum)} " \
            "(> 10,000 cd/m²)",
          )
        end

        def add_display_info(
          red_x, red_y, green_x, green_y, blue_x, blue_y,
          white_x, white_y, max_lum, min_lum
        )
          add_info(
            "mastering display: " \
            "R=(#{format_coordinate(red_x)},#{format_coordinate(red_y)}), " \
            "G=(#{format_coordinate(green_x)},#{format_coordinate(green_y)}), " \
            "B=(#{format_coordinate(blue_x)},#{format_coordinate(blue_y)})",
          )

          add_info(
            "white point: " \
            "(#{format_coordinate(white_x)},#{format_coordinate(white_y)})",
          )

          add_info(
            "luminance range: " \
            "#{format_luminance(min_lum)} - #{format_luminance(max_lum)} cd/m²",
          )
        end

        def read_uint16(data, offset)
          data[offset, 2].unpack1("n")
        end

        def read_uint32(data, offset)
          data[offset, 4].unpack1("N")
        end

        def format_coordinate(value)
          (value * COORDINATE_SCALE).round(5).to_s
        end

        def format_luminance(value)
          (value * LUMINANCE_SCALE).round(4).to_s
        end
      end
    end
  end
end
