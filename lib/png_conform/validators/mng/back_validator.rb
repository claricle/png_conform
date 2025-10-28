# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG BACK (Background color) chunks
      #
      # The BACK chunk specifies the background color and image for the MNG
      # frame.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Must appear before MEND
      # - Length must be 6, 7, or 10 bytes
      # - Mandatory background flag: 0 or 1
      # - Tile mode: 0-3
      class BackValidator < BaseValidator
        VALID_LENGTHS = [6, 7, 10].freeze

        def validate
          return false unless check_crc

          unless context.retrieve(:mhdr_present)
            add_error("BACK must appear after MHDR")
            return false
          end

          if context.seen?("MEND")
            add_error("BACK must appear before MEND")
            return false
          end

          data = chunk.chunk_data

          unless VALID_LENGTHS.include?(data.length)
            add_error(
              "BACK chunk must be 6, 7, or 10 bytes, " \
              "got #{data.length}",
            )
            return false
          end

          # Red, Green, Blue (2 bytes each)
          red, green, blue = data[0, 6].unpack("nnn")
          context.store(:back_red, red)
          context.store(:back_green, green)
          context.store(:back_blue, blue)

          if data.length >= 7
            # Mandatory background flag (1 byte)
            mandatory = data.getbyte(6)

            unless [0, 1].include?(mandatory)
              add_error(
                "BACK mandatory flag must be 0 or 1, got #{mandatory}",
              )
              return false
            end

            context.store(:back_mandatory, mandatory)
          end

          if data.length == 10
            # Background image ID (2 bytes)
            bg_image_id = data[7, 2].unpack1("n")

            # Background tile mode (1 byte)
            tile_mode = data.getbyte(9)

            unless (0..3).cover?(tile_mode)
              add_error(
                "BACK tile mode must be 0-3, got #{tile_mode}",
              )
              return false
            end

            context.store(:back_image_id, bg_image_id)
            context.store(:back_tile_mode, tile_mode)
          end

          context.store(:back_present, true)
          true
        end
      end
    end
  end
end
