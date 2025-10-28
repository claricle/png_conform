# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG SEEK (Seek to saved state) chunks
      #
      # The SEEK chunk restores the MNG state previously saved with SAVE.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Length must be 0 bytes (empty)
      # - Should have corresponding SAVE before it
      # - Must appear before MEND
      class SeekValidator < BaseValidator
        EXPECTED_LENGTH = 0

        def validate
          return false unless check_crc
          return false unless check_length(EXPECTED_LENGTH)

          unless context.retrieve(:mhdr_present)
            add_error("SEEK must appear after MHDR")
            return false
          end

          if context.seen?("MEND")
            add_error("SEEK must appear before MEND")
            return false
          end

          unless context.retrieve(:save_present)
            add_warning("SEEK without corresponding SAVE")
          end

          context.store(:seek_present, true)
          true
        end
      end
    end
  end
end
