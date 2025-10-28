# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG DEFI (Object definition) chunks
      #
      # The DEFI chunk defines an object and its location within the MNG frame.
      # It specifies the object ID, clipping boundaries, and concrete flag.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Length must be 2, 3, 4, 12, or 28 bytes
      # - Object ID >= 0
      # - Clipping boundaries must be valid if specified
      # - Must appear before MEND
      class DefiValidator < BaseValidator
        VALID_LENGTHS = [2, 3, 4, 12, 28].freeze

        def validate
          return false unless check_crc

          unless context.retrieve(:mhdr_present)
            add_error("DEFI must appear after MHDR")
            return false
          end

          if context.seen?("MEND")
            add_error("DEFI must appear before MEND")
            return false
          end

          data = chunk.chunk_data
          unless VALID_LENGTHS.include?(data.length)
            add_error(
              "DEFI chunk must be 2, 3, 4, 12, or 28 bytes, " \
              "got #{data.length}",
            )
            return false
          end

          pos = 0

          # Object ID (2 bytes)
          object_id = data.unpack1("n")
          pos += 2
          context.store(:defi_object_id, object_id)

          if data.length >= 3
            # Do-not-show flag (1 byte)
            do_not_show = data.getbyte(pos)
            pos += 1
            context.store(:defi_do_not_show, do_not_show)
          end

          if data.length >= 4
            # Concrete flag (1 byte)
            concrete = data.getbyte(pos)
            pos += 1
            context.store(:defi_concrete, concrete)
          end

          if data.length >= 12
            # X and Y location (4 bytes each)
            x_location, y_location = data[pos, 8].unpack("NN")
            pos += 8
            context.store(:defi_x_location, x_location)
            context.store(:defi_y_location, y_location)
          end

          if data.length == 28
            # Clipping boundaries (4 x 4 bytes)
            left, right, top, bottom = data[pos, 16].unpack("NNNN")

            # Validate clipping boundaries
            if left > right
              add_error(
                "DEFI left clipping (#{left}) must not exceed " \
                "right clipping (#{right})",
              )
              return false
            end

            if top > bottom
              add_error(
                "DEFI top clipping (#{top}) must not exceed " \
                "bottom clipping (#{bottom})",
              )
              return false
            end

            context.store(:defi_clip_left, left)
            context.store(:defi_clip_right, right)
            context.store(:defi_clip_top, top)
            context.store(:defi_clip_bottom, bottom)
          end

          context.store(:defi_present, true)
          true
        end
      end
    end
  end
end
