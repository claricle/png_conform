# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Critical
      # Validator for PNG PLTE (Palette) chunk
      #
      # PLTE defines the color palette for indexed-color images.
      # - Required for color type 3 (indexed-color)
      # - Optional for color types 2 and 6 (truecolor and truecolor+alpha)
      # - Forbidden for color types 0 and 4 (grayscale and grayscale+alpha)
      #
      # Validation rules from PNG spec:
      # - Length must be divisible by 3 (RGB triplets)
      # - Must contain 1-256 palette entries
      # - For indexed-color, number of entries must not exceed 2^bit_depth
      # - Must appear before first IDAT chunk
      # - Must appear before bKGD, hIST, tRNS chunks
      class PlteValidator < BaseValidator
        # Maximum number of palette entries
        MAX_ENTRIES = 256

        # Validate PLTE chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_divisible_by_3
          return false unless check_entry_count
          return false unless check_color_type_compatibility
          return false unless check_bit_depth_compatibility

          store_palette_info
          true
        end

        private

        # Check that chunk length is divisible by 3
        def check_divisible_by_3
          length = chunk.chunk_data.length
          return true if (length % 3).zero?

          add_error("invalid PLTE length (#{length}, must be divisible by 3)")
          false
        end

        # Check number of palette entries
        def check_entry_count
          length = chunk.chunk_data.length
          entries = length / 3

          if entries.zero?
            add_error("invalid PLTE chunk (no entries)")
            return false
          end

          if entries > MAX_ENTRIES
            add_error("invalid PLTE chunk (#{entries} entries, " \
                      "maximum is #{MAX_ENTRIES})")
            return false
          end

          true
        end

        # Check PLTE compatibility with color type
        def check_color_type_compatibility
          color_type = context.retrieve(:color_type)
          return true unless color_type # IHDR not validated yet

          case color_type
          when 0, 4
            # Grayscale and grayscale+alpha: PLTE forbidden
            add_error("PLTE chunk not allowed for grayscale images")
            false
          when 3
            # Indexed-color: PLTE required (checked elsewhere)
            true
          when 2, 6
            # Truecolor and truecolor+alpha: PLTE optional (suggested palette)
            add_info("PLTE chunk present (suggested palette)")
            true
          else
            # Unknown color type
            add_warning("PLTE chunk present but color type unknown")
            true
          end
        end

        # Check palette size vs bit depth for indexed-color images
        def check_bit_depth_compatibility
          color_type = context.retrieve(:color_type)
          bit_depth = context.retrieve(:bit_depth)

          return true unless color_type == 3 # Only for indexed-color
          return true unless bit_depth # Bit depth not available

          max_entries = 2**bit_depth
          entries = chunk.chunk_data.length / 3

          return true if entries <= max_entries

          add_error("PLTE chunk has #{entries} entries but bit depth " \
                    "#{bit_depth} allows maximum of #{max_entries}")
          false
        end

        # Store palette information in context
        def store_palette_info
          entries = chunk.chunk_data.length / 3
          context.store(:palette_entries, entries)
          context.store(:has_palette, true)
        end
      end
    end
  end
end
