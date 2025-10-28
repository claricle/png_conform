# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG cHRM (Primary Chromaticities and White Point) chunk
      #
      # cHRM specifies the chromaticity coordinates of the display primaries
      # and white point:
      # - White Point x (4 bytes)
      # - White Point y (4 bytes)
      # - Red x (4 bytes)
      # - Red y (4 bytes)
      # - Green x (4 bytes)
      # - Green y (4 bytes)
      # - Blue x (4 bytes)
      # - Blue y (4 bytes)
      #
      # All values are encoded as integers representing the value * 100,000.
      #
      # Validation rules from PNG spec:
      # - Must be exactly 32 bytes
      # - Must appear before PLTE and IDAT
      # - Only one cHRM chunk allowed
      # - Values should be in range 0.0-0.8 (0-80000)
      # - If sRGB present, should match sRGB values
      class ChrmValidator < BaseValidator
        # Standard sRGB chromaticity values (* 100000)
        SRGB_VALUES = {
          white_x: 31_270,
          white_y: 32_900,
          red_x: 64_000,
          red_y: 33_000,
          green_x: 30_000,
          green_y: 60_000,
          blue_x: 15_000,
          blue_y: 6_000,
        }.freeze

        # Tolerance for sRGB comparison
        SRGB_TOLERANCE = 5

        # Validate cHRM chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_length(32)
          return false unless check_position
          return false unless check_uniqueness
          return false unless check_values

          check_srgb_consistency

          store_chrm_info
          true
        end

        private

        # Check cHRM position relative to other chunks
        def check_position
          valid = true

          # cHRM should appear before PLTE and IDAT
          if context.seen?("PLTE")
            add_warning("cHRM chunk after PLTE (should be before)")
          end

          if context.seen?("IDAT")
            add_error("cHRM chunk after IDAT (must be before)")
            valid = false
          end

          valid
        end

        # Check that only one cHRM chunk is present
        def check_uniqueness
          if context.seen?("cHRM")
            add_error("duplicate cHRM chunk")
            return false
          end
          true
        end

        # Check chromaticity values
        def check_values
          data = chunk.chunk_data
          values = data.unpack("N8")

          white_x, white_y, red_x, red_y, green_x, green_y, blue_x, blue_y = values

          valid = true

          # Check ranges (typically 0.0-0.8, or 0-80000)
          valid &= check_chromaticity(white_x, "white point x")
          valid &= check_chromaticity(white_y, "white point y")
          valid &= check_chromaticity(red_x, "red x")
          valid &= check_chromaticity(red_y, "red y")
          valid &= check_chromaticity(green_x, "green x")
          valid &= check_chromaticity(green_y, "green y")
          valid &= check_chromaticity(blue_x, "blue x")
          valid &= check_chromaticity(blue_y, "blue y")

          valid
        end

        # Check individual chromaticity value
        def check_chromaticity(value, name)
          # Values are typically 0.0-0.8 (0-80000)
          if value > 100_000
            add_warning("#{name} chromaticity (#{value / 100_000.0}) " \
                        "exceeds typical range (0.0-1.0)")
          end
          true
        end

        # Check consistency with sRGB chunk if present
        def check_srgb_consistency
          return unless context.retrieve(:uses_srgb)

          data = chunk.chunk_data
          values = data.unpack("N8")

          white_x, white_y, red_x, red_y, green_x, green_y, blue_x, blue_y = values

          mismatches = []
          mismatches << "white point x" unless close_to?(white_x,
                                                         SRGB_VALUES[:white_x])
          mismatches << "white point y" unless close_to?(white_y,
                                                         SRGB_VALUES[:white_y])
          mismatches << "red x" unless close_to?(red_x, SRGB_VALUES[:red_x])
          mismatches << "red y" unless close_to?(red_y, SRGB_VALUES[:red_y])
          mismatches << "green x" unless close_to?(green_x,
                                                   SRGB_VALUES[:green_x])
          mismatches << "green y" unless close_to?(green_y,
                                                   SRGB_VALUES[:green_y])
          mismatches << "blue x" unless close_to?(blue_x, SRGB_VALUES[:blue_x])
          mismatches << "blue y" unless close_to?(blue_y, SRGB_VALUES[:blue_y])

          return unless mismatches.any?

          add_warning("cHRM values don't match sRGB: #{mismatches.join(', ')}")
        end

        # Check if value is close to expected sRGB value
        def close_to?(actual, expected)
          (actual - expected).abs <= SRGB_TOLERANCE
        end

        # Store chromaticity information in context
        def store_chrm_info
          data = chunk.chunk_data
          values = data.unpack("N8")

          white_x, white_y, red_x, red_y, green_x, green_y, blue_x, blue_y = values

          context.store(:chromaticity, {
                          white_x: white_x / 100_000.0,
                          white_y: white_y / 100_000.0,
                          red_x: red_x / 100_000.0,
                          red_y: red_y / 100_000.0,
                          green_x: green_x / 100_000.0,
                          green_y: green_y / 100_000.0,
                          blue_x: blue_x / 100_000.0,
                          blue_y: blue_y / 100_000.0,
                        })

          add_info("cHRM: white=(#{format('%.4f', white_x / 100_000.0)}, " \
                   "#{format('%.4f', white_y / 100_000.0)})")
        end
      end
    end
  end
end
