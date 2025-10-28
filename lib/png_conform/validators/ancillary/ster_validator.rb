# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG sTER (Stereo Image Indicator) chunk
      #
      # sTER indicates that the image is part of a stereo image pair:
      # - Mode (1 byte)
      #
      # Validation rules from PNG spec:
      # - Chunk must be exactly 1 byte
      # - Mode must be 0 (cross-fuse) or 1 (diverging-fuse)
      # - Must appear before IDAT chunk
      # - Only one sTER chunk allowed
      class SterValidator < BaseValidator
        # Expected chunk length
        EXPECTED_LENGTH = 1

        # Valid stereo modes
        MODE_CROSS_FUSE = 0
        MODE_DIVERGING_FUSE = 1
        VALID_MODES = [MODE_CROSS_FUSE, MODE_DIVERGING_FUSE].freeze

        # Mode names for display
        MODE_NAMES = {
          MODE_CROSS_FUSE => "cross-fuse layout",
          MODE_DIVERGING_FUSE => "diverging-fuse layout",
        }.freeze

        # Validate sTER chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_uniqueness
          return false unless check_position
          return false unless check_length
          return false unless check_mode

          store_stereo_info
          true
        end

        private

        # Check that only one sTER chunk exists
        def check_uniqueness
          if context.retrieve(:has_stereo)
            add_error("Multiple sTER chunks (only one allowed)")
            return false
          end

          true
        end

        # Check that sTER appears before IDAT
        def check_position
          if context.seen?("IDAT")
            add_error("sTER chunk after IDAT chunk")
            return false
          end

          true
        end

        # Check chunk length
        def check_length
          actual_length = chunk.chunk_data.length

          unless actual_length == EXPECTED_LENGTH
            add_error("sTER chunk wrong length (#{actual_length} byte(s), " \
                      "expected #{EXPECTED_LENGTH})")
            return false
          end

          true
        end

        # Check stereo mode
        def check_mode
          data = chunk.chunk_data
          mode = data[0].ord

          unless VALID_MODES.include?(mode)
            add_error("sTER invalid mode (#{mode}, must be 0 or 1)")
            return false
          end

          true
        end

        # Store stereo information in context
        def store_stereo_info
          data = chunk.chunk_data
          mode = data[0].ord
          mode_name = MODE_NAMES[mode]

          # Store in context
          context.store(:has_stereo, true)
          context.store(:stereo_mode, mode)

          # Add info about the stereo mode
          add_info("sTER: #{mode_name} (mode #{mode})")
        end
      end
    end
  end
end
