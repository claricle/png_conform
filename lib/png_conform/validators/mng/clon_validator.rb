# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG CLON (Clone object) chunks
      #
      # The CLON chunk creates a copy of an existing object.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Length must be 4 or 16 bytes
      # - Must appear before MEND
      class ClonValidator < BaseValidator
        VALID_LENGTHS = [4, 16].freeze

        def validate
          return false unless check_crc

          unless context.retrieve(:mhdr_present)
            add_error("CLON must appear after MHDR")
            return false
          end

          if context.seen?("MEND")
            add_error("CLON must appear before MEND")
            return false
          end

          data = chunk.chunk_data

          unless VALID_LENGTHS.include?(data.length)
            add_error(
              "CLON chunk must be 4 or 16 bytes, got #{data.length}",
            )
            return false
          end

          context.store(:clon_present, true)
          true
        end
      end
    end
  end
end
