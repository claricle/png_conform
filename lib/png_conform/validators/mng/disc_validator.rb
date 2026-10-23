# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG DISC (Discard objects) chunks
      #
      # The DISC chunk discards one or more objects from the MNG object buffer.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Length must be a multiple of 2 bytes (list of object IDs)
      # - Must appear before MEND
      class DiscValidator < BaseValidator
        def validate
          return false unless check_crc(id: "mng.DISC.crc")

          unless context.retrieve(:mhdr_present)
            add_error("mng.DISC.after-mhdr", "DISC must appear after MHDR")
            return false
          end

          if context.seen?("MEND")
            add_error("mng.DISC.before-mend", "DISC must appear before MEND")
            return false
          end

          data = chunk.chunk_data

          if data.length.odd?
            add_error("mng.DISC.length-multiple-of-2", "DISC chunk length must be a multiple of 2, " \
                                                       "got #{data.length}", field: "length", expected: "multiple of 2", actual: data.length)
            return false
          end

          context.store(:disc_present, true)
          true
        end
      end
    end
  end
end
