# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Jng
      # Validator for JHDR (JNG Header) chunk
      #
      # The JHDR chunk is the first chunk in a JNG (JPEG Network Graphics)
      # datastream and contains information about the JPEG image.
      #
      # Structure (16 bytes):
      # - width (4 bytes): Image width in pixels
      # - height (4 bytes): Image height in pixels
      # - color_type (1 byte): Color type (8, 10, 12, 14)
      # - image_sample_depth (1 byte): JPEG sample depth (8 or 12)
      # - image_compression_method (1 byte): JPEG compression (8)
      # - interlace_method (1 byte): Interlace method (0)
      # - alpha_sample_depth (1 byte): Alpha channel sample depth
      # - alpha_compression_method (1 byte): Alpha compression method
      # - alpha_filter_method (1 byte): Alpha filter method
      # - alpha_interlace_method (1 byte): Alpha interlace method
      # - 4 reserved bytes
      #
      class JhdrValidator < BaseValidator
        VALID_COLOR_TYPES = [8, 10, 12, 14].freeze
        VALID_SAMPLE_DEPTHS = [8, 12].freeze

        # Validate JHDR chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_length(16)

          # JHDR must be first chunk in JNG
          unless context.chunks_seen.empty?
            add_error("JHDR must be the first chunk in JNG datastream")
            return false
          end

          data = chunk.chunk_data

          # Extract fields
          width = data[0, 4].unpack1("N")
          height = data[4, 4].unpack1("N")
          color_type = data[8].unpack1("C")
          image_sample_depth = data[9].unpack1("C")
          image_compression = data[10].unpack1("C")
          interlace = data[11].unpack1("C")

          valid = true

          # Validate dimensions
          valid &= check_dimensions(width, height)

          # Validate color type
          valid &= check_enum(color_type, VALID_COLOR_TYPES, "color type")

          # Validate sample depth
          valid &= check_enum(image_sample_depth, VALID_SAMPLE_DEPTHS,
                              "image sample depth")

          # Validate compression method (must be 8 for baseline JPEG)
          if image_compression != 8
            add_error("invalid image compression method (#{image_compression}, " \
                      "must be 8)")
            valid = false
          end

          # Validate interlace method (must be 0)
          if interlace != 0
            add_error("invalid interlace method (#{interlace}, must be 0)")
            valid = false
          end

          if valid
            store_jhdr_info(width, height, color_type,
                            image_sample_depth)
          end

          valid
        end

        private

        # Check image dimensions
        def check_dimensions(width, height)
          valid = true

          if width.zero?
            add_error("invalid image width (0)")
            valid = false
          end

          if height.zero?
            add_error("invalid image height (0)")
            valid = false
          end

          valid
        end

        # Store JHDR information in context for use by other validators
        def store_jhdr_info(width, height, color_type, image_sample_depth)
          context.store(:jhdr_width, width)
          context.store(:jhdr_height, height)
          context.store(:jhdr_color_type, color_type)
          context.store(:jhdr_image_sample_depth, image_sample_depth)
          context.store(:jhdr_present, true)
        end
      end
    end
  end
end
