# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG bKGD (Background Color) chunk
      #
      # bKGD specifies a default background color for displaying the image:
      # - For indexed-color: 1 byte (palette index)
      # - For grayscale: 2 bytes (gray value)
      # - For truecolor: 6 bytes (RGB values)
      #
      # Validation rules from PNG spec:
      # - Length depends on color type
      # - Must appear before IDAT
      # - For indexed-color, must appear after PLTE
      # - Only one bKGD chunk allowed
      # - Palette index must be valid
      class BkgdValidator < BaseValidator
        # Validate bKGD chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_position
          return false unless check_uniqueness
          return false unless check_length_for_color_type
          return false unless check_value

          store_background_info
          true
        end

        private

        # Check bKGD position relative to other chunks
        def check_position
          valid = true

          # bKGD must appear before IDAT
          if context.seen?("IDAT")
            add_error("bKGD chunk after IDAT (must be before)")
            valid = false
          end

          # For indexed-color, bKGD must appear after PLTE
          color_type = context.retrieve(:color_type)
          if color_type == 3 && !context.seen?("PLTE")
            add_error("bKGD chunk before PLTE for indexed-color image")
            valid = false
          end

          valid
        end

        # Check that only one bKGD chunk is present
        def check_uniqueness
          if context.seen?("bKGD")
            add_error("duplicate bKGD chunk")
            return false
          end
          true
        end

        # Check bKGD length for color type
        def check_length_for_color_type
          color_type = context.retrieve(:color_type)
          return true unless color_type

          chunk.chunk_data.bytesize

          case color_type
          when 0, 4
            # Grayscale or grayscale+alpha: 2 bytes
            check_length(2)
          when 2, 6
            # Truecolor or truecolor+alpha: 6 bytes
            check_length(6)
          when 3
            # Indexed-color: 1 byte
            check_length(1)
          else
            true
          end
        end

        # Check background value validity
        def check_value
          color_type = context.retrieve(:color_type)
          return true unless color_type

          data = chunk.chunk_data

          case color_type
          when 3
            # Indexed-color: check palette index
            index = data.unpack1("C")
            palette_entries = context.retrieve(:palette_entries)

            if palette_entries && index >= palette_entries
              add_error("bKGD palette index (#{index}) exceeds " \
                        "palette size (#{palette_entries})")
              return false
            end
          end

          true
        end

        # Store background information in context
        def store_background_info
          color_type = context.retrieve(:color_type)
          data = chunk.chunk_data

          case color_type
          when 0, 4
            # Grayscale: store gray value
            gray = data.unpack1("n")
            context.store(:background_gray, gray)
            add_info("bKGD: gray = #{gray}")
          when 2, 6
            # Truecolor: store RGB values
            r, g, b = data.unpack("nnn")
            context.store(:background_color, { r: r, g: g, b: b })
            add_info("bKGD: RGB = (#{r}, #{g}, #{b})")
          when 3
            # Indexed-color: store palette index
            index = data.unpack1("C")
            context.store(:background_index, index)
            add_info("bKGD: palette index = #{index}")
          end

          context.store(:has_background, true)
        end
      end
    end
  end
end
