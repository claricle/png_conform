# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG sRGB (Standard RGB Color Space) chunk
      #
      # sRGB indicates that the image uses the sRGB color space:
      # - Rendering intent (1 byte):
      #   0 = Perceptual
      #   1 = Relative colorimetric
      #   2 = Saturation
      #   3 = Absolute colorimetric
      #
      # Validation rules from PNG spec:
      # - Must be exactly 1 byte
      # - Must appear before PLTE and IDAT
      # - Only one sRGB chunk allowed
      # - Rendering intent must be 0-3
      # - If both sRGB and gAMA present, gAMA should be 45455 (gamma 2.2)
      # - If both sRGB and cHRM present, values should match sRGB
      class SrgbValidator < BaseValidator
        # Rendering intents
        INTENT_PERCEPTUAL = 0
        INTENT_RELATIVE_COLORIMETRIC = 1
        INTENT_SATURATION = 2
        INTENT_ABSOLUTE_COLORIMETRIC = 3

        INTENT_NAMES = {
          INTENT_PERCEPTUAL => "perceptual",
          INTENT_RELATIVE_COLORIMETRIC => "relative colorimetric",
          INTENT_SATURATION => "saturation",
          INTENT_ABSOLUTE_COLORIMETRIC => "absolute colorimetric",
        }.freeze

        # Expected gamma for sRGB (45455 = 2.2)
        SRGB_GAMMA = 45_455

        # Validate sRGB chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_length(1)
          return false unless check_position
          return false unless check_uniqueness
          return false unless check_intent

          check_gamma_consistency

          store_srgb_info
          true
        end

        private

        # Check sRGB position relative to other chunks
        def check_position
          valid = true

          # sRGB should appear before PLTE and IDAT
          if context.seen?("PLTE")
            add_warning("sRGB chunk after PLTE (should be before)")
          end

          if context.seen?("IDAT")
            add_error("sRGB chunk after IDAT (must be before)")
            valid = false
          end

          valid
        end

        # Check that only one sRGB chunk is present
        def check_uniqueness
          if context.seen?("sRGB")
            add_error("duplicate sRGB chunk")
            return false
          end
          true
        end

        # Check rendering intent
        def check_intent
          intent = chunk.chunk_data.unpack1("C")
          check_enum(intent, INTENT_NAMES.keys, "rendering intent")
        end

        # Check consistency with gAMA chunk if present
        def check_gamma_consistency
          return unless context.seen?("gAMA")

          gamma = context.retrieve(:gamma)
          return unless gamma

          return unless gamma != SRGB_GAMMA

          actual_gamma = gamma / 100_000.0
          add_warning("sRGB chunk present but gAMA is #{actual_gamma} " \
                      "(should be 2.2 for sRGB)")
        end

        # Store sRGB information in context
        def store_srgb_info
          intent = chunk.chunk_data.unpack1("C")
          context.store(:srgb_intent, intent)
          context.store(:uses_srgb, true)

          intent_name = INTENT_NAMES[intent]
          add_info("sRGB: #{intent_name} rendering intent")
        end
      end
    end
  end
end
