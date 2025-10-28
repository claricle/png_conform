# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG ENDL (End loop) chunks
      #
      # The ENDL chunk marks the end of a loop started by a LOOP chunk.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Length must be 1 byte
      # - Nesting level must match corresponding LOOP
      # - Must have corresponding LOOP before it
      # - Must appear before MEND
      class EndlValidator < BaseValidator
        EXPECTED_LENGTH = 1

        def validate
          return false unless check_crc
          return false unless check_length(EXPECTED_LENGTH)

          unless context.retrieve(:mhdr_present)
            add_error("ENDL must appear after MHDR")
            return false
          end

          if context.seen?("MEND")
            add_error("ENDL must appear before MEND")
            return false
          end

          unless context.retrieve(:loop_present)
            add_error("ENDL must appear after LOOP")
            return false
          end

          # Nesting level (1 byte)
          nesting_level = chunk.chunk_data.getbyte(0)

          # Validate loop nesting
          loop_stack = context.retrieve(:loop_stack) || []

          if loop_stack.empty?
            add_error("ENDL without corresponding LOOP")
            return false
          elsif loop_stack.last != nesting_level
            add_error(
              "ENDL nesting level (#{nesting_level}) does not match " \
              "LOOP nesting level (#{loop_stack.last})",
            )
            return false
          else
            loop_stack.pop
            context.store(:loop_stack, loop_stack)
          end

          context.store(:endl_nesting_level, nesting_level)
          context.store(:endl_present, true)
          true
        end
      end
    end
  end
end
