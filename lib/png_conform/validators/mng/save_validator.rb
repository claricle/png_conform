# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG SAVE (Save state) chunks
      #
      # The SAVE chunk saves the current MNG state for later restoration with SEEK.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Length must be 0 bytes (empty)
      # - Must appear before MEND
      class SaveValidator < BaseValidator
        EXPECTED_LENGTH = 0

        def validate
          return false unless check_crc(id: "mng.SAVE.crc")
          return false unless check_length(EXPECTED_LENGTH, id: "mng.SAVE.length")

          # Must appear after MHDR
          unless context.retrieve(:mhdr_present)
            add_error("mng.SAVE.after-mhdr", "SAVE must appear after MHDR")
            return false
          end

          # Must appear before MEND
          if context.seen?("MEND")
            add_error("mng.SAVE.before-mend", "SAVE must appear before MEND")
            return false
          end

          context.store(:save_present, true)
          true
        end
      end
    end
  end
end
