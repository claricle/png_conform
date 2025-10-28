# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG MOVE (Move object) chunks
      #
      # The MOVE chunk moves an object to a new location.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Must appear before MEND
      # - Length must be 13 bytes
      # - Contains first object ID, last object ID, move type, and X/Y offsets
      class MoveValidator < BaseValidator
        EXPECTED_LENGTH = 13

        def validate
          return false unless check_crc

          unless context.retrieve(:mhdr_present)
            add_error("MOVE must appear after MHDR")
            return false
          end

          if context.seen?("MEND")
            add_error("MOVE must appear before MEND")
            return false
          end

          data = chunk.chunk_data

          unless data.length == EXPECTED_LENGTH
            add_error(
              "MOVE chunk must be #{EXPECTED_LENGTH} bytes, " \
              "got #{data.length}",
            )
            return false
          end

          # Parse MOVE data
          # First object ID (2 bytes)
          # Last object ID (2 bytes)
          # Move type (1 byte)
          # X offset (4 bytes, signed)
          # Y offset (4 bytes, signed)
          first_id, last_id, move_type, x_offset, y_offset =
            data.unpack("nnCl>l>")

          context.store(:move_first_id, first_id)
          context.store(:move_last_id, last_id)
          context.store(:move_type, move_type)
          context.store(:move_x_offset, x_offset)
          context.store(:move_y_offset, y_offset)
          context.store(:move_present, true)
          true
        end
      end
    end
  end
end
