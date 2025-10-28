# frozen_string_literal: true

module PngConform
  module Validators
    module Mng
      # Validator for MHDR (MNG Header) chunk
      #
      # The MHDR chunk is the first chunk in a MNG datastream and contains
      # basic information about the MNG file.
      #
      # Structure (28 bytes):
      # - frame_width (4 bytes): Frame width in pixels
      # - frame_height (4 bytes): Frame height in pixels
      # - ticks_per_second (4 bytes): Nominal tick rate
      # - nominal_layer_count (4 bytes): Nominal layer count
      # - nominal_frame_count (4 bytes): Nominal frame count
      # - nominal_play_time (4 bytes): Nominal play time
      # - simplicity_profile (4 bytes): Simplicity profile flags
      #
      class MhdrValidator < BaseValidator
        CHUNK_TYPE = "MHDR"
        EXPECTED_LENGTH = 28

        def validate
          return false unless check_crc
          return false unless check_length(EXPECTED_LENGTH)

          # MHDR must be first chunk
          unless context.chunks_seen.empty?
            add_error("MHDR must be the first chunk in MNG file")
            return false
          end

          data = chunk.chunk_data

          # Extract fields
          frame_width = data[0..3].unpack1("N")
          frame_height = data[4..7].unpack1("N")
          ticks_per_second = data[8..11].unpack1("N")
          nominal_layer_count = data[12..15].unpack1("N")
          nominal_frame_count = data[16..19].unpack1("N")
          nominal_play_time = data[20..23].unpack1("N")
          simplicity_profile = data[24..27].unpack1("N")

          # Validate dimensions
          valid = true
          if frame_width.zero? || frame_height.zero?
            add_error("MHDR frame dimensions must be > 0")
            valid = false
          end

          if valid
            # Store in context
            context.store(:mhdr_frame_width, frame_width)
            context.store(:mhdr_frame_height, frame_height)
            context.store(:mhdr_ticks_per_second, ticks_per_second)
            context.store(:mhdr_nominal_layer_count, nominal_layer_count)
            context.store(:mhdr_nominal_frame_count, nominal_frame_count)
            context.store(:mhdr_nominal_play_time, nominal_play_time)
            context.store(:mhdr_simplicity_profile, simplicity_profile)
            context.store(:mhdr_present, true)
          end

          valid
        end
      end
    end
  end
end
