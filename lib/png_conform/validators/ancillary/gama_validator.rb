# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG gAMA (Image Gamma) chunk
      #
      # gAMA specifies the gamma of the image for proper display.
      # The value is encoded as a 4-byte unsigned integer representing
      # gamma times 100,000.
      #
      # Validation rules from PNG spec:
      # - Must be exactly 4 bytes
      # - Must appear before PLTE and IDAT
      # - Only one gAMA chunk allowed
      # - Value of 0 is invalid
      # - Typical values: 45455 (gamma 2.2), 100000 (gamma 1.0)
      class GamaValidator < BaseValidator
        # Common gamma values (gamma * 100000)
        GAMMA_2_2 = 45_455  # Standard display gamma
        GAMMA_1_0 = 100_000 # Linear gamma

        # Validate gAMA chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_length(4)
          return false unless check_position
          return false unless check_uniqueness
          return false unless check_value

          store_gamma_info
          true
        end

        private

        # Check gAMA position relative to other chunks
        def check_position
          valid = true

          # gAMA should appear before PLTE and IDAT
          if context.seen?("PLTE")
            add_error("gAMA chunk after PLTE (should be before)")
            valid = false
          end

          if context.seen?("IDAT")
            add_error("gAMA chunk after IDAT (must be before)")
            valid = false
          end

          valid
        end

        # Check that only one gAMA chunk is present
        def check_uniqueness
          if context.seen?("gAMA")
            add_error("duplicate gAMA chunk")
            return false
          end
          true
        end

        # Check gamma value
        def check_value
          gamma = chunk.chunk_data.unpack1("N")

          if gamma.zero?
            add_error("invalid gAMA value (0)")
            return false
          end

          # Check sRGB interaction
          if context.seen?("sRGB") && gamma != GAMMA_2_2
            add_warning("gAMA value #{gamma} with sRGB present (should be #{GAMMA_2_2} for gamma 2.2)")
          end

          # Info about common values
          case gamma
          when GAMMA_2_2
            add_info("gAMA: 2.2 (standard display gamma)")
          when GAMMA_1_0
            add_info("gAMA: 1.0 (linear)")
          else
            actual_gamma = gamma / 100_000.0
            add_info("gAMA: #{format('%.5f', actual_gamma)}")
          end

          true
        end

        # Store gamma information in context
        def store_gamma_info
          gamma = chunk.chunk_data.unpack1("N")
          context.store(:gamma, gamma)
          context.store(:gamma_value, gamma / 100_000.0)
        end
      end
    end
  end
end
