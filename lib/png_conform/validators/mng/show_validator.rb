# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG SHOW (Show object) chunks
      #
      # The SHOW chunk makes a previously defined object visible.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Must appear before MEND
      # - Length must be 0 or 2 bytes
      # - If 2 bytes, contains object ID to show
      class ShowValidator < BaseValidator
        VALID_LENGTHS = [0, 2].freeze

        def validate
          return false unless check_crc

          unless context.retrieve(:mhdr_present)
            add_error("SHOW must appear after MHDR")
            return false
          end

          if context.seen?("MEND")
            add_error("SHOW must appear before MEND")
            return false
          end

          data = chunk.chunk_data

          unless VALID_LENGTHS.include?(data.length)
            add_error(
              "SHOW chunk must be 0 or 2 bytes, got #{data.length}",
            )
            return false
          end

          if data.length == 2
            # Object ID (2 bytes)
            object_id = data.unpack1("n")
            context.store(:show_object_id, object_id)
          end

          context.store(:show_present, true)
          true
        end
      end
    end
  end
end
