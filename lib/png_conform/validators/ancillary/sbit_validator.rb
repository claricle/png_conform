# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG sBIT (Significant Bits) chunk
      #
      # sBIT indicates the number of significant bits in the original image:
      # - For grayscale: 1 byte (significant grayscale bits)
      # - For truecolor: 3 bytes (R, G, B significant bits)
      # - For indexed-color: 3 bytes (R, G, B significant bits)
      # - For grayscale+alpha: 2 bytes (gray, alpha significant bits)
      # - For truecolor+alpha: 4 bytes (R, G, B, alpha significant bits)
      #
      # Validation rules from PNG spec:
      # - Length depends on color type
      # - Must appear before PLTE and IDAT
      # - Only one sBIT chunk allowed
      # - Each value must be > 0 and <= sample depth
      class SbitValidator < BaseValidator
        # Validate sBIT chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_position
          return false unless check_uniqueness
          return false unless check_length_for_color_type
          return false unless check_values

          store_sbit_info
          true
        end

        private

        # Check sBIT position relative to other chunks
        def check_position
          valid = true

          # sBIT should appear before PLTE and IDAT
          if context.seen?("PLTE")
            add_warning("sBIT chunk after PLTE (should be before)")
          end

          if context.seen?("IDAT")
            add_error("sBIT chunk after IDAT (must be before)")
            valid = false
          end

          valid
        end

        # Check that only one sBIT chunk is present
        def check_uniqueness
          if context.seen?("sBIT")
            add_error("duplicate sBIT chunk")
            return false
          end
          true
        end

        # Check sBIT length for color type
        def check_length_for_color_type
          color_type = context.retrieve(:color_type)
          return true unless color_type

          expected_length = case color_type
                            when 0 then 1  # Grayscale
                            when 2 then 3  # Truecolor
                            when 3 then 3  # Indexed-color
                            when 4 then 2  # Grayscale + alpha
                            when 6 then 4  # Truecolor + alpha
                            else
                              return true
                            end

          check_length(expected_length)
        end

        # Check significant bit values
        def check_values
          color_type = context.retrieve(:color_type)
          bit_depth = context.retrieve(:bit_depth)
          return true unless color_type && bit_depth

          data = chunk.chunk_data
          valid = true

          case color_type
          when 0
            # Grayscale
            gray_bits = data[0].unpack1("C")
            valid &= check_sbit_value(gray_bits, bit_depth, "gray")
          when 2
            # Truecolor
            red, green, blue = data.unpack("CCC")
            valid &= check_sbit_value(red, bit_depth, "red")
            valid &= check_sbit_value(green, bit_depth, "green")
            valid &= check_sbit_value(blue, bit_depth, "blue")
          when 3
            # Indexed-color (refers to palette sample depth, which is always 8)
            red, green, blue = data.unpack("CCC")
            valid &= check_sbit_value(red, 8, "red")
            valid &= check_sbit_value(green, 8, "green")
            valid &= check_sbit_value(blue, 8, "blue")
          when 4
            # Grayscale + alpha
            gray, alpha = data.unpack("CC")
            valid &= check_sbit_value(gray, bit_depth, "gray")
            valid &= check_sbit_value(alpha, bit_depth, "alpha")
          when 6
            # Truecolor + alpha
            red, green, blue, alpha = data.unpack("CCCC")
            valid &= check_sbit_value(red, bit_depth, "red")
            valid &= check_sbit_value(green, bit_depth, "green")
            valid &= check_sbit_value(blue, bit_depth, "blue")
            valid &= check_sbit_value(alpha, bit_depth, "alpha")
          end

          valid
        end

        # Check individual significant bit value
        def check_sbit_value(value, max_depth, name)
          if value.zero?
            add_error("#{name} significant bits cannot be 0")
            return false
          end

          if value > max_depth
            add_error("#{name} significant bits (#{value}) exceeds " \
                      "sample depth (#{max_depth})")
            return false
          end

          true
        end

        # Store significant bit information in context
        def store_sbit_info
          color_type = context.retrieve(:color_type)
          data = chunk.chunk_data

          case color_type
          when 0
            gray = data[0].unpack1("C")
            context.store(:significant_bits, { gray: gray })
            add_info("sBIT: gray=#{gray}")
          when 2
            red, green, blue = data.unpack("CCC")
            context.store(:significant_bits,
                          { red: red, green: green, blue: blue })
            add_info("sBIT: R=#{red}, G=#{green}, B=#{blue}")
          when 3
            red, green, blue = data.unpack("CCC")
            context.store(:significant_bits,
                          { red: red, green: green, blue: blue })
            add_info("sBIT: R=#{red}, G=#{green}, B=#{blue}")
          when 4
            gray, alpha = data.unpack("CC")
            context.store(:significant_bits, { gray: gray, alpha: alpha })
            add_info("sBIT: gray=#{gray}, alpha=#{alpha}")
          when 6
            red, green, blue, alpha = data.unpack("CCCC")
            context.store(:significant_bits,
                          { red: red, green: green, blue: blue, alpha: alpha })
            add_info("sBIT: R=#{red}, G=#{green}, B=#{blue}, A=#{alpha}")
          end
        end
      end
    end
  end
end
