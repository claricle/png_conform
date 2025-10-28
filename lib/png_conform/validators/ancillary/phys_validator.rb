# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG pHYs (Physical Pixel Dimensions) chunk
      #
      # pHYs specifies the intended pixel size or aspect ratio:
      # - Pixels per unit, X axis (4 bytes)
      # - Pixels per unit, Y axis (4 bytes)
      # - Unit specifier (1 byte): 0 = unknown, 1 = meters
      #
      # Validation rules from PNG spec:
      # - Must be exactly 9 bytes
      # - Must appear before IDAT
      # - Only one pHYs chunk allowed
      # - Unit specifier must be 0 or 1
      class PhysValidator < BaseValidator
        # Unit specifiers
        UNIT_UNKNOWN = 0
        UNIT_METER = 1

        # Common DPI values (pixels per inch)
        DPI_72 = 2835   # 72 DPI in pixels per meter
        DPI_96 = 3780   # 96 DPI in pixels per meter
        DPI_150 = 5906  # 150 DPI in pixels per meter
        DPI_300 = 11_811 # 300 DPI in pixels per meter

        # Validate pHYs chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_length(9)
          return false unless check_position
          return false unless check_uniqueness
          return false unless check_unit

          store_phys_info
          true
        end

        private

        # Check pHYs position relative to other chunks
        def check_position
          # pHYs should appear before IDAT
          if context.seen?("IDAT")
            add_error("pHYs chunk after IDAT (must be before)")
            return false
          end
          true
        end

        # Check that only one pHYs chunk is present
        def check_uniqueness
          if context.seen?("pHYs")
            add_error("duplicate pHYs chunk")
            return false
          end
          true
        end

        # Check unit specifier
        def check_unit
          data = chunk.chunk_data
          unit = data[8].unpack1("C")

          check_enum(unit, [UNIT_UNKNOWN, UNIT_METER], "unit specifier")
        end

        # Store physical dimensions in context
        def store_phys_info
          data = chunk.chunk_data
          pixels_per_unit_x = data[0, 4].unpack1("N")
          pixels_per_unit_y = data[4, 4].unpack1("N")
          unit = data[8].unpack1("C")

          context.store(:phys_x, pixels_per_unit_x)
          context.store(:phys_y, pixels_per_unit_y)
          context.store(:phys_unit, unit)

          # Calculate aspect ratio
          if pixels_per_unit_x.positive? && pixels_per_unit_y.positive?
            aspect = pixels_per_unit_x.to_f / pixels_per_unit_y
            context.store(:pixel_aspect_ratio, aspect)

            if (aspect - 1.0).abs > 0.01
              add_info("pHYs: non-square pixels " \
                       "(aspect ratio #{format('%.3f', aspect)})")
            end
          end

          # Provide DPI information if unit is meters
          unless unit == UNIT_METER && pixels_per_unit_x == pixels_per_unit_y
            return
          end

          dpi = (pixels_per_unit_x * 0.0254).round
          add_info("pHYs: #{dpi} DPI")
        end
      end
    end
  end
end
