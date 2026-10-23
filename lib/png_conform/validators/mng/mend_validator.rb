# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validator for MEND (MNG End) chunk
      #
      # The MEND chunk marks the end of a MNG datastream.
      # It must be the last chunk in the file and contains no data.
      #
      class MendValidator < BaseValidator
        CHUNK_TYPE = "MEND"
        EXPECTED_LENGTH = 0

        def validate
          return false unless check_crc(id: "mng.MEND.crc")
          return false unless check_length(EXPECTED_LENGTH, id: "mng.MEND.length")

          # MEND must have MHDR before it
          unless context.seen?("MHDR")
            add_error("mng.MEND.requires-mhdr", "MEND requires MHDR chunk")
            return false
          end

          # MEND should be last chunk (this will be validated by orchestration)
          true
        end
      end
    end
  end
end
