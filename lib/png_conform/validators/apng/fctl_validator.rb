# frozen_string_literal: true

module PngConform
  module Validators
    module Apng
      # Validator for fcTL (Frame Control) chunk
      #
      # The fcTL chunk specifies the parameters of each frame in an animated PNG.
      #
      # Structure (26 bytes):
      # - sequence_number (4 bytes): Sequence number (starts at 0)
      # - width (4 bytes): Frame width in pixels
      # - height (4 bytes): Frame height in pixels
      # - x_offset (4 bytes): X position at which to render frame
      # - y_offset (4 bytes): Y position at which to render frame
      # - delay_num (2 bytes): Frame delay numerator
      # - delay_den (2 bytes): Frame delay denominator
      # - dispose_op (1 byte): Disposal operation (0-2)
      # - blend_op (1 byte): Blend operation (0-1)
      #
      # Constraints:
      # - Must have acTL chunk before any fcTL
      # - Frame dimensions must be <= IHDR dimensions
      # - Frame position + size must fit within IHDR dimensions
      # - Sequence numbers must be consecutive
      # - dispose_op: 0=NONE, 1=BACKGROUND, 2=PREVIOUS
      # - blend_op: 0=SOURCE, 1=OVER
      #
      class FctlValidator < BaseValidator
        CHUNK_TYPE = "fcTL"
        EXPECTED_LENGTH = 26

        DISPOSE_OP_NONE = 0
        DISPOSE_OP_BACKGROUND = 1
        DISPOSE_OP_PREVIOUS = 2

        BLEND_OP_SOURCE = 0
        BLEND_OP_OVER = 1

        def validate
          return unless check_crc
          return unless check_length(EXPECTED_LENGTH)

          validate_structure
          validate_frame_dimensions
          validate_sequence_number
        end

        private

        def validate_structure
          data = chunk.chunk_data

          # Extract all fields
          sequence_number = data[0..3].unpack1("N")
          width = data[4..7].unpack1("N")
          height = data[8..11].unpack1("N")
          data[12..15].unpack1("N")
          data[16..19].unpack1("N")
          delay_num = data[20..21].unpack1("n")
          delay_den = data[22..23].unpack1("n")
          dispose_op = data[24].unpack1("C")
          blend_op = data[25].unpack1("C")

          # Store in context
          context.store(:last_fctl_sequence, sequence_number)
          context.store(:fctl_count, (context.retrieve(:fctl_count) || 0) + 1)

          # Validate frame dimensions
          if width.zero? || height.zero?
            add_error("fcTL width and height must be > 0")
            return false
          end

          # Validate dispose_op
          unless check_enum(dispose_op, [DISPOSE_OP_NONE, DISPOSE_OP_BACKGROUND,
                                         DISPOSE_OP_PREVIOUS], "dispose_op")
            return false
          end

          # Validate blend_op
          unless check_enum(blend_op, [BLEND_OP_SOURCE, BLEND_OP_OVER],
                            "blend_op")
            return false
          end

          # Validate delay
          if delay_den.zero?
            # delay_den of 0 means denominator is 100
            context.store(:frame_delay, delay_num / 100.0)
          else
            context.store(:frame_delay, delay_num.to_f / delay_den)
          end

          true
        end

        def validate_frame_dimensions
          ihdr_width = context.retrieve(:ihdr_width)
          ihdr_height = context.retrieve(:ihdr_height)

          return true unless ihdr_width && ihdr_height

          data = chunk.chunk_data
          width = data[4..7].unpack1("N")
          height = data[8..11].unpack1("N")
          x_offset = data[12..15].unpack1("N")
          y_offset = data[16..19].unpack1("N")

          # Frame must fit within IHDR dimensions
          if width > ihdr_width || height > ihdr_height
            add_error("fcTL frame dimensions exceed IHDR dimensions")
            return false
          end

          # Frame position + size must fit within IHDR
          if x_offset + width > ihdr_width
            add_error("fcTL frame extends beyond IHDR width")
            return false
          end

          if y_offset + height > ihdr_height
            add_error("fcTL frame extends beyond IHDR height")
            return false
          end

          true
        end

        def validate_sequence_number
          # Check if acTL exists
          unless context.retrieve(:actl_num_frames)
            add_error("fcTL requires acTL chunk")
            return false
          end

          data = chunk.chunk_data
          sequence_number = data[0..3].unpack1("N")
          expected_sequence = context.retrieve(:expected_apng_sequence) || 0

          if sequence_number != expected_sequence
            add_error("fcTL sequence number mismatch " \
                      "(expected #{expected_sequence}, got #{sequence_number})")
            return false
          end

          # Update expected sequence for next frame chunk
          context.store(:expected_apng_sequence, expected_sequence + 1)

          true
        end
      end
    end
  end
end
