# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG tRNS (Transparency) chunk
      #
      # tRNS specifies transparency information:
      # - For grayscale: 2-byte gray sample value
      # - For truecolor: 6-byte RGB sample values
      # - For indexed-color: alpha values for palette entries
      #
      # Validation rules from PNG spec:
      # - Must appear before IDAT
      # - Only one tRNS chunk allowed
      # - For indexed-color, must appear after PLTE
      # - For indexed-color, length must not exceed palette size
      # - Not allowed for grayscale+alpha or truecolor+alpha
      class TrnsValidator < BaseValidator
        # Validate tRNS chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_position
          return false unless check_uniqueness
          return false unless check_color_type_compatibility
          return false unless check_length_for_color_type

          store_transparency_info
          true
        end

        private

        # Check tRNS position relative to other chunks
        def check_position
          valid = true

          # tRNS must appear before IDAT
          if context.seen?("IDAT")
            add_error("tRNS chunk after IDAT (must be before)")
            valid = false
          end

          # For indexed-color, tRNS must appear after PLTE
          color_type = context.retrieve(:color_type)
          if color_type == 3 && !context.seen?("PLTE")
            add_error("tRNS chunk before PLTE for indexed-color image")
            valid = false
          end

          valid
        end

        # Check that only one tRNS chunk is present
        def check_uniqueness
          if context.retrieve(:has_transparency)
            add_error("duplicate tRNS chunk")
            return false
          end
          true
        end

        # Check tRNS compatibility with color type
        def check_color_type_compatibility
          color_type = context.retrieve(:color_type)
          return true unless color_type # IHDR not validated yet

          case color_type
          when 0, 2, 3
            # Grayscale, truecolor, indexed-color: tRNS allowed
            true
          when 4, 6
            # Grayscale+alpha, truecolor+alpha: tRNS forbidden
            add_error("tRNS chunk not allowed for color type with " \
                      "alpha channel")
            false
          else
            add_warning("tRNS chunk present but color type unknown")
            true
          end
        end

        # Check tRNS length for color type
        def check_length_for_color_type
          color_type = context.retrieve(:color_type)
          return true unless color_type

          length = chunk.chunk_data.length

          case color_type
          when 0
            # Grayscale: must be 2 bytes
            check_length(2)
          when 2
            # Truecolor: must be 6 bytes (RGB)
            check_length(6)
          when 3
            # Indexed-color: 1-256 bytes (alpha for each palette entry)
            palette_entries = context.retrieve(:palette_entries)

            # Check if palette exists
            unless context.retrieve(:has_palette)
              add_error("tRNS chunk for indexed-color without PLTE chunk")
              return false
            end

            # Check length doesn't exceed palette size
            if palette_entries && length > palette_entries
              add_error("tRNS has more entries than palette " \
                        "(#{length} > #{palette_entries})")
              return false
            end

            return true if length.between?(1, 256)

            add_error("invalid tRNS length for indexed-color " \
                      "(#{length}, must be 1-256)")
            false
          else
            true
          end
        end

        # Store transparency information in context
        def store_transparency_info
          context.store(:has_transparency, true)

          color_type = context.retrieve(:color_type)
          data = chunk.chunk_data

          case color_type
          when 0
            # Grayscale: store gray value
            gray = data.unpack1("n")
            context.store(:transparent_gray, gray)
          when 2
            # Truecolor: store RGB values
            r, g, b = data.unpack("nnn")
            context.store(:transparent_color, { r: r, g: g, b: b })
          when 3
            # Indexed-color: store alpha values
            alphas = data.unpack("C*")
            context.store(:palette_alphas, alphas)
            context.store(:transparent_entries, alphas.length)
          end
        end
      end
    end
  end
end
