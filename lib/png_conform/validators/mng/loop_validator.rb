# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG LOOP (Loop control) chunks
      #
      # The LOOP chunk marks the beginning of a loop in an MNG animation.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Length must be 5 or 6 bytes
      # - Nesting level must be >= 0
      # - Iteration count must be >= 0 (0 = infinite)
      # - Must have corresponding ENDL
      # - Must appear before MEND
      class LoopValidator < BaseValidator
        VALID_LENGTHS = [5, 6].freeze

        def validate
          return false unless check_crc

          unless context.retrieve(:mhdr_present)
            add_error("LOOP must appear after MHDR")
            return false
          end

          data = chunk.chunk_data
          unless VALID_LENGTHS.include?(data.length)
            add_error(
              "LOOP chunk must be 5 or 6 bytes, got #{data.length}",
            )
            return false
          end

          if context.seen?("MEND")
            add_error("LOOP must appear before MEND")
            return false
          end

          # Nesting level (1 byte)
          nesting_level = data.getbyte(0)

          # Iteration count (4 bytes)
          iteration_count = data[1, 4].unpack1("N")

          context.store(:loop_nesting_level, nesting_level)
          context.store(:loop_iteration_count, iteration_count)

          if data.length == 6
            # Termination condition (1 byte)
            termination = data.getbyte(5)

            unless (0..3).cover?(termination)
              add_error(
                "LOOP termination condition must be 0-3, got #{termination}",
              )
              return false
            end

            context.store(:loop_termination, termination)
          end

          # Track loop nesting
          loop_stack = context.retrieve(:loop_stack) || []
          loop_stack.push(nesting_level)
          context.store(:loop_stack, loop_stack)

          context.store(:loop_present, true)
          true
        end
      end
    end
  end
end
