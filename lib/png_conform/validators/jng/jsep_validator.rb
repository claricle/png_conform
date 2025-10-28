# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Jng
      # Validates JNG JSEP (8-bit/12-bit image separator) chunks
      #
      # The JSEP chunk separates 8-bit and 12-bit JPEG image data in a JNG file.
      # It is only present when the sample depth is 12 bits and both 8-bit and
      # 12-bit JPEG data are included.
      #
      # Validation rules:
      # - Must appear after JHDR
      # - Length must be 0 (no data)
      # - Only valid when sample depth is 12 bits
      # - Separates 8-bit JDAT chunks from 12-bit JDAT chunks
      # - Must appear before IEND
      class JsepValidator < BaseValidator
        # Validate JSEP chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_length(0)

          valid = true

          # JSEP must appear after JHDR
          unless context.retrieve(:jhdr_present)
            add_error("JSEP must appear after JHDR")
            valid = false
          end

          # JSEP must appear before IEND
          if context.seen?("IEND")
            add_error("JSEP must appear before IEND")
            valid = false
          end

          # JSEP is only valid with 12-bit sample depth
          sample_depth = context.retrieve(:jhdr_image_sample_depth)
          if sample_depth && sample_depth != 12
            add_error("JSEP is only valid with 12-bit sample depth, " \
                      "got #{sample_depth}-bit")
            valid = false
          end

          # JSEP should appear after at least one JDAT (8-bit data)
          # and before the 12-bit JDAT chunks
          unless context.retrieve(:jdat_count).to_i.positive?
            add_warning("JSEP should appear after 8-bit JDAT chunks")
          end

          if valid
            # Mark that JSEP was seen
            context.store(:jsep_present, true)
          end

          valid
        end
      end
    end
  end
end
