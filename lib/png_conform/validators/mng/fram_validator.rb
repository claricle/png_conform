# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG FRAM (Frame parameters) chunks
      #
      # The FRAM chunk sets frame parameters including framing mode, subframe
      # name, change interframe delay, change timeout, change layer clipping,
      # and change sync ID.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Length can be 0, 1, or variable (with parameters)
      # - Framing mode: 0-4
      # - All parameters optional based on change flags
      # - Must appear before MEND
      class FramValidator < BaseValidator
        VALID_FRAMING_MODES = (0..4).to_a.freeze

        def validate
          return false unless check_crc

          unless context.retrieve(:mhdr_present)
            add_error("FRAM must appear after MHDR")
            return false
          end

          if context.seen?("MEND")
            add_error("FRAM must appear before MEND")
            return false
          end

          data = chunk.chunk_data

          # Empty FRAM is valid
          if data.empty?
            context.store(:fram_present, true)
            return true
          end

          pos = 0

          # Framing mode (1 byte)
          if pos < data.length
            framing_mode = data.getbyte(pos)
            pos += 1

            unless VALID_FRAMING_MODES.include?(framing_mode)
              add_error(
                "Invalid FRAM framing mode: #{framing_mode} (must be 0-4)",
              )
              return false
            end

            context.store(:fram_framing_mode, framing_mode)
          end

          # Parse optional change flags and parameters
          if pos < data.length
            # Subframe name length (1 byte) + name
            name_length = data.getbyte(pos)
            pos += 1

            if pos + name_length > data.length
              add_error("FRAM subframe name extends beyond chunk")
              return false
            end

            if name_length.positive?
              subframe_name = data[pos, name_length]
              pos += name_length
              context.store(:fram_subframe_name, subframe_name)
            end
          end

          # Remaining parameters are change flags and their values
          # We don't need to parse all of them in detail for basic validation
          # Just ensure the chunk length is reasonable
          if pos < data.length
            # Store that FRAM has parameters
            context.store(:fram_has_parameters, true)
          end

          context.store(:fram_present, true)
          true
        end
      end
    end
  end
end
