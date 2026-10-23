# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG DHDR (Delta-PNG header) chunks
      #
      # The DHDR chunk marks the beginning of an embedded delta-PNG (difference
      # image) in an MNG file. It has a similar structure to IHDR but is used
      # for delta frames.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Length must be 4, 12, or 20 bytes
      # - Object ID must be >= 0
      # - Image type: 0 (PNG), 2 (JNG), or 4 (PNG with alpha separation)
      # - Delta type: 0 (entire replacement), 1-7 (various delta types)
      # - Block width/height must be > 0 if specified
      class DhdrValidator < BaseValidator
        VALID_LENGTHS = [4, 12, 20].freeze
        VALID_IMAGE_TYPES = [0, 2, 4].freeze
        VALID_DELTA_TYPES = (0..7).to_a.freeze

        def validate
          return false unless check_crc(id: "mng.DHDR.crc")

          unless context.retrieve(:mhdr_present)
            add_error("mng.DHDR.after-mhdr", "DHDR must appear after MHDR")
            return false
          end

          if context.seen?("MEND")
            add_error("mng.DHDR.before-mend", "DHDR must appear before MEND")
            return false
          end

          data = chunk.chunk_data
          unless VALID_LENGTHS.include?(data.length)
            add_error("mng.DHDR.length", "DHDR chunk must be 4, 12, or 20 bytes, " \
                                         "got #{data.length}", field: "length", expected: "4, 12, or 20", actual: data.length)
            return false
          end

          values = data.unpack("N*")

          # All formats have object ID
          object_id = values[0]
          context.store(:dhdr_object_id, object_id)

          if data.length >= 12
            # 12 or 20 byte format includes image type and delta type
            image_type = values[1]
            delta_type = values[2]

            unless VALID_IMAGE_TYPES.include?(image_type)
              add_error("mng.DHDR.image-type", "Invalid DHDR image type: #{image_type} " \
                                               "(must be 0, 2, or 4)", field: "image_type", expected: "0, 2, or 4", actual: image_type)
              return false
            end

            unless VALID_DELTA_TYPES.include?(delta_type)
              add_error("mng.DHDR.delta-type", "Invalid DHDR delta type: #{delta_type} " \
                                               "(must be 0-7)", field: "delta_type", expected: "0-7", actual: delta_type)
              return false
            end

            context.store(:dhdr_image_type, image_type)
            context.store(:dhdr_delta_type, delta_type)
          end

          if data.length == 20
            # 20 byte format includes block dimensions
            block_width = values[3]
            block_height = values[4]

            if block_width.zero?
              add_error("mng.DHDR.block-width-zero", "DHDR block width must be greater than 0", field: "block_width", expected: ">0", actual: 0)
              return false
            end

            if block_height.zero?
              add_error("mng.DHDR.block-height-zero", "DHDR block height must be greater than 0", field: "block_height", expected: ">0", actual: 0)
              return false
            end

            context.store(:dhdr_block_width, block_width)
            context.store(:dhdr_block_height, block_height)
          end

          # DHDR begins a new object definition
          context.store(:in_dhdr_section, true)
          context.store(:dhdr_present, true)
          true
        end
      end
    end
  end
end
