# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG CLIP (Clip object) chunks
      #
      # The CLIP chunk defines clipping boundaries for subsequent objects.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Must appear before MEND
      # - Length must be 21 bytes
      # - Contains first/last object IDs, clip type, and clipping boundaries
      class ClipValidator < BaseValidator
        EXPECTED_LENGTH = 21

        def validate
          return false unless check_crc

          unless context.retrieve(:mhdr_present)
            add_error("CLIP must appear after MHDR")
            return false
          end

          if context.seen?("MEND")
            add_error("CLIP must appear before MEND")
            return false
          end

          data = chunk.chunk_data

          unless data.length == EXPECTED_LENGTH
            add_error(
              "CLIP chunk must be #{EXPECTED_LENGTH} bytes, " \
              "got #{data.length}",
            )
            return false
          end

          # Parse CLIP data
          # First object ID (2 bytes)
          # Last object ID (2 bytes)
          # Clip type (1 byte)
          # Left delta (4 bytes, signed)
          # Right delta (4 bytes, signed)
          # Top delta (4 bytes, signed)
          # Bottom delta (4 bytes, signed)
          first_id, last_id, clip_type, left, right, top, bottom =
            data.unpack("nnCl>l>l>l>")

          context.store(:clip_first_id, first_id)
          context.store(:clip_last_id, last_id)
          context.store(:clip_type, clip_type)
          context.store(:clip_left, left)
          context.store(:clip_right, right)
          context.store(:clip_top, top)
          context.store(:clip_bottom, bottom)
          context.store(:clip_present, true)
          true
        end
      end
    end
  end
end
