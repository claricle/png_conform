# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validates MNG TERM (Termination action) chunks
      #
      # The TERM chunk specifies the action to take when the animation terminates.
      #
      # Validation rules:
      # - Must appear after MHDR
      # - Length must be 1 or 10 bytes
      # - Termination action: 0-3
      # - Action after iterations: 0-2
      # - Must appear before MEND
      class TermValidator < BaseValidator
        VALID_LENGTHS = [1, 10].freeze
        VALID_TERMINATION_ACTIONS = (0..3).to_a.freeze
        VALID_AFTER_ITERATIONS = (0..2).to_a.freeze

        def validate
          return false unless check_crc

          unless context.retrieve(:mhdr_present)
            add_error("TERM must appear after MHDR")
            return false
          end

          data = chunk.chunk_data
          unless VALID_LENGTHS.include?(data.length)
            add_error(
              "TERM chunk must be 1 or 10 bytes, got #{data.length}",
            )
            return false
          end

          if context.seen?("MEND")
            add_error("TERM must appear before MEND")
            return false
          end

          # Termination action (1 byte)
          termination_action = data.getbyte(0)

          unless VALID_TERMINATION_ACTIONS.include?(termination_action)
            add_error(
              "Invalid TERM termination action: #{termination_action} " \
              "(must be 0-3)",
            )
            return false
          end

          context.store(:term_termination_action, termination_action)

          if data.length == 10
            # Action after iterations (1 byte)
            after_iterations = data.getbyte(1)

            unless VALID_AFTER_ITERATIONS.include?(after_iterations)
              add_error(
                "Invalid TERM action after iterations: #{after_iterations} " \
                "(must be 0-2)",
              )
              return false
            end

            # Delay (4 bytes)
            delay = data[2, 4].unpack1("N")

            # Maximum iterations (4 bytes)
            max_iterations = data[6, 4].unpack1("N")

            context.store(:term_after_iterations, after_iterations)
            context.store(:term_delay, delay)
            context.store(:term_max_iterations, max_iterations)
          end

          context.store(:term_present, true)
          true
        end
      end
    end
  end
end
