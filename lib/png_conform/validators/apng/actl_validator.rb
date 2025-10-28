# frozen_string_literal: true

module PngConform
  module Validators
    module Apng
      # Validator for acTL (Animation Control) chunk
      #
      # The acTL chunk is an ancillary chunk that contains information about
      # the animation: the number of frames and the number of times to loop.
      #
      # Structure:
      # - num_frames (4 bytes): Number of frames (unsigned int)
      # - num_plays (4 bytes): Number of times to loop (0 = infinite)
      #
      # Constraints:
      # - Must appear before IDAT
      # - Must appear before any fcTL chunks
      # - num_frames must be > 0
      # - If present, at least one fcTL chunk must exist
      #
      class ActlValidator < BaseValidator
        CHUNK_TYPE = "acTL"
        EXPECTED_LENGTH = 8

        def validate
          return unless check_crc
          return unless check_length(EXPECTED_LENGTH)

          validate_structure
          validate_ordering
          validate_animation_parameters
        end

        private

        def validate_structure
          data = chunk.chunk_data

          # Extract fields
          num_frames = data[0..3].unpack1("N")
          num_plays = data[4..7].unpack1("N")

          # Store in context for cross-chunk validation
          context.store(:actl_num_frames, num_frames)
          context.store(:actl_num_plays, num_plays)

          # Validate num_frames
          if num_frames.zero?
            add_error("acTL num_frames must be > 0")
            return false
          end

          # num_plays can be 0 (infinite) or any positive number
          true
        end

        def validate_ordering
          # acTL must appear before IDAT
          if context.seen?("IDAT")
            add_error("acTL must appear before IDAT")
            return false
          end

          # acTL must appear before any fcTL
          if context.seen?("fcTL")
            add_error("acTL must appear before first fcTL")
            return false
          end

          true
        end

        def validate_animation_parameters
          # Check if this is truly an animated PNG
          # (will be validated after all chunks are processed)
          true
        end
      end
    end
  end
end
