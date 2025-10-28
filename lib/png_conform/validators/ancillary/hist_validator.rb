# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG hIST (Palette Histogram) chunk
      #
      # hIST provides the approximate usage frequency of each palette entry:
      # - One 2-byte value per palette entry
      # - Values are proportional, not absolute
      #
      # Validation rules from PNG spec:
      # - Must appear after PLTE chunk
      # - Must appear before first IDAT chunk
      # - Must have exactly 2 bytes per palette entry
      # - Only valid for color type 3 (indexed color)
      # - Only one hIST chunk allowed
      class HistValidator < BaseValidator
        # Validate hIST chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_uniqueness
          return false unless check_color_type
          return false unless check_palette_exists
          return false unless check_position
          return false unless check_length

          store_histogram_info
          true
        end

        private

        # Check that only one hIST chunk exists
        def check_uniqueness
          if context.retrieve(:has_histogram)
            add_error("Multiple hIST chunks (only one allowed)")
            return false
          end

          true
        end

        # Check that color type is indexed (3)
        def check_color_type
          color_type = context.retrieve(:color_type)

          unless color_type
            add_error("hIST chunk before IHDR")
            return false
          end

          unless color_type == 3
            add_error("hIST chunk invalid for color type #{color_type} " \
                      "(only valid for indexed color)")
            return false
          end

          true
        end

        # Check that PLTE chunk exists
        def check_palette_exists
          has_palette = context.retrieve(:has_palette)

          unless has_palette
            add_error("hIST chunk without preceding PLTE chunk")
            return false
          end

          true
        end

        # Check that hIST appears after PLTE but before IDAT
        def check_position
          # Must come after PLTE
          unless context.seen?("PLTE")
            add_error("hIST chunk before PLTE chunk")
            return false
          end

          # Must come before IDAT
          if context.seen?("IDAT")
            add_error("hIST chunk after IDAT chunk")
            return false
          end

          true
        end

        # Check that length matches palette size
        def check_length
          palette_entries = context.retrieve(:palette_entries)
          expected_length = palette_entries * 2
          actual_length = chunk.chunk_data.length

          unless actual_length == expected_length
            add_error("hIST chunk wrong length (#{actual_length} bytes, " \
                      "expected #{expected_length} for #{palette_entries} " \
                      "palette entries)")
            return false
          end

          true
        end

        # Store histogram information in context
        def store_histogram_info
          data = chunk.chunk_data
          palette_entries = context.retrieve(:palette_entries)

          # Read frequency values (2 bytes each, big-endian)
          frequencies = []
          (0...palette_entries).each do |i|
            offset = i * 2
            freq = (data[offset].ord << 8) | data[offset + 1].ord
            frequencies << freq
          end

          # Store in context
          context.store(:has_histogram, true)
          context.store(:histogram_frequencies, frequencies)

          # Add info about histogram
          total = frequencies.sum
          if total.zero?
            add_info("hIST: #{palette_entries} entries (all zero)")
          else
            # Find most and least used colors
            max_freq = frequencies.max
            max_idx = frequencies.index(max_freq)
            min_freq = frequencies.reject(&:zero?).min || 0
            min_idx = frequencies.index(min_freq)

            add_info("hIST: #{palette_entries} palette entries, " \
                     "most used: index #{max_idx} (#{max_freq}), " \
                     "least used: index #{min_idx} (#{min_freq})")
          end
        end
      end
    end
  end
end
