# frozen_string_literal: true

module PngConform
  module Validators
    module Apng
      # Validator for fdAT (Frame Data) chunk
      #
      # The fdAT chunk contains the compressed image data for a single frame
      # in an animated PNG. It is similar to IDAT but includes a sequence number.
      #
      # Structure:
      # - sequence_number (4 bytes): Sequence number
      # - frame_data (remaining bytes): Compressed image data
      #
      # Constraints:
      # - Must have fcTL chunk before fdAT
      # - Sequence numbers must be consecutive (continuing from fcTL)
      # - Must have acTL chunk present
      # - Frame data must be valid zlib compressed data
      #
      class FdatValidator < BaseValidator
        CHUNK_TYPE = "fdAT"
        MIN_LENGTH = 5 # At least 4 bytes for sequence + 1 byte data

        def validate
          return unless check_crc
          return unless validate_min_length

          validate_structure
          validate_sequence_number
          validate_ordering
        end

        private

        def validate_min_length
          actual = chunk.chunk_data.length
          if actual < MIN_LENGTH
            add_error("fdAT chunk too short (#{actual} bytes, " \
                      "minimum #{MIN_LENGTH})")
            return false
          end
          true
        end

        def validate_structure
          data = chunk.chunk_data

          # Extract sequence number
          sequence_number = data[0..3].unpack1("N")

          # Store in context
          context.store(:last_fdat_sequence, sequence_number)
          context.store(:fdat_count, (context.retrieve(:fdat_count) || 0) + 1)

          # Frame data is the rest (starting at byte 4)
          frame_data = data[4..]

          if frame_data.nil? || frame_data.empty?
            add_error("fdAT has no frame data")
            return false
          end

          # Store frame data length for statistics
          context.store(:fdat_data_length,
                        (context.retrieve(:fdat_data_length) || 0) + frame_data.length)

          true
        end

        def validate_sequence_number
          # Check if acTL exists
          unless context.retrieve(:actl_num_frames)
            add_error("fdAT requires acTL chunk")
            return false
          end

          data = chunk.chunk_data
          sequence_number = data[0..3].unpack1("N")
          expected_sequence = context.retrieve(:expected_apng_sequence)

          # First fdAT should follow fcTL sequences
          if expected_sequence.nil?
            add_error("fdAT must follow fcTL chunk")
            return false
          end

          if sequence_number != expected_sequence
            add_error("fdAT sequence number mismatch " \
                      "(expected #{expected_sequence}, got #{sequence_number})")
            return false
          end

          # Update expected sequence for next chunk
          context.store(:expected_apng_sequence, expected_sequence + 1)

          true
        end

        def validate_ordering
          # fdAT must have corresponding fcTL
          fctl_count = context.retrieve(:fctl_count) || 0
          context.retrieve(:fdat_count) || 0

          # Each frame should have fcTL followed by fdAT(s)
          # We can have multiple fdAT chunks per frame, but must have at least one fcTL
          if fctl_count.zero?
            add_error("fdAT chunk requires fcTL chunk")
            return false
          end

          true
        end
      end
    end
  end
end
