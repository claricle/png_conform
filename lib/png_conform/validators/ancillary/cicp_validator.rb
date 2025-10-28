# frozen_string_literal: true

module PngConform
  module Validators
    module Ancillary
      # Validator for cICP (Coding-Independent Code Points) chunk
      #
      # The cICP chunk specifies color space information using MPEG/ITU-T standards.
      # Introduced in PNG 3rd edition (ISO/IEC 15948-1:2023).
      #
      # Structure:
      # - Color primaries (1 byte): ITU-T H.273 / ISO/IEC 23091-2
      # - Transfer function (1 byte): ITU-T H.273 / ISO/IEC 23091-2
      # - Matrix coefficients (1 byte): ITU-T H.273 / ISO/IEC 23091-2
      # - Video full range flag (1 byte): 0 or 1
      #
      # Constraints:
      # - Must contain exactly 4 bytes
      # - Must appear before PLTE and IDAT
      # - At most one cICP chunk allowed
      # - Should not coexist with iCCP or sRGB chunks
      #
      class CicpValidator < BaseValidator
        CHUNK_TYPE = "cICP"

        # Valid color primaries codes (ITU-T H.273 / ISO/IEC 23091-2)
        VALID_COLOR_PRIMARIES = [
          0,   # Reserved
          1,   # BT.709
          2,   # Unspecified
          4,   # BT.470M
          5,   # BT.470BG
          6,   # BT.601
          7,   # SMPTE 240M
          8,   # Generic film
          9,   # BT.2020
          10,  # XYZ
          11,  # SMPTE 431
          12,  # SMPTE 432
          22, # EBU Tech 3213
        ].freeze

        # Valid transfer function codes (ITU-T H.273 / ISO/IEC 23091-2)
        VALID_TRANSFER_FUNCTIONS = [
          0,   # Reserved
          1,   # BT.709
          2,   # Unspecified
          4,   # Gamma 2.2
          5,   # Gamma 2.8
          6,   # BT.601
          7,   # SMPTE 240M
          8,   # Linear
          9,   # Logarithmic (100:1 range)
          10,  # Logarithmic (100*sqrt(10):1 range)
          11,  # IEC 61966-2-4
          12,  # BT.1361
          13,  # sRGB/sYCC
          14,  # BT.2020 (10-bit)
          15,  # BT.2020 (12-bit)
          16,  # SMPTE ST 2084 (PQ)
          17,  # SMPTE ST 428
          18, # HLG
        ].freeze

        # Valid matrix coefficients codes (ITU-T H.273 / ISO/IEC 23091-2)
        VALID_MATRIX_COEFFICIENTS = [
          0,   # Identity
          1,   # BT.709
          2,   # Unspecified
          4,   # FCC
          5,   # BT.470BG
          6,   # BT.601
          7,   # SMPTE 240M
          8,   # YCgCo
          9,   # BT.2020 non-constant luminance
          10,  # BT.2020 constant luminance
          11,  # SMPTE 2085
          12,  # Chromaticity-derived non-constant luminance
          13,  # Chromaticity-derived constant luminance
          14, # ICtCp
        ].freeze

        def validate
          check_chunk_length
          check_uniqueness
          check_position
          validate_fields if chunk.chunk_data.bytesize == 4
          check_conflicts
        end

        private

        def check_chunk_length
          return if check_length(4)

          add_error("invalid chunk length: #{chunk.chunk_data.bytesize} bytes")
        end

        def check_uniqueness
          return unless context.seen?(CHUNK_TYPE)

          add_error("multiple cICP chunks not allowed")
        end

        def check_position
          add_error("cICP must appear before PLTE") if context.seen?("PLTE")

          return unless context.seen?("IDAT")

          add_error("cICP must appear before IDAT")
        end

        def validate_fields
          data = chunk.chunk_data.bytes

          validate_color_primaries(data[0])
          validate_transfer_function(data[1])
          validate_matrix_coefficients(data[2])
          validate_video_full_range_flag(data[3])
        end

        def validate_color_primaries(value)
          unless VALID_COLOR_PRIMARIES.include?(value)
            add_error(
              "invalid color primaries: #{value} " \
              "(valid: #{VALID_COLOR_PRIMARIES.join(', ')})",
            )
          end

          return unless value.zero?

          add_warning("color primaries = 0 (reserved)")
        end

        def validate_transfer_function(value)
          unless VALID_TRANSFER_FUNCTIONS.include?(value)
            add_error(
              "invalid transfer function: #{value} " \
              "(valid: #{VALID_TRANSFER_FUNCTIONS.join(', ')})",
            )
          end

          return unless value.zero?

          add_warning("transfer function = 0 (reserved)")
        end

        def validate_matrix_coefficients(value)
          unless VALID_MATRIX_COEFFICIENTS.include?(value)
            add_error(
              "invalid matrix coefficients: #{value} " \
              "(valid: #{VALID_MATRIX_COEFFICIENTS.join(', ')})",
            )
          end

          return unless value.zero? && rgb_color?

          add_info(
            "matrix coefficients = 0 (identity) is recommended for RGB",
          )
        end

        def validate_video_full_range_flag(value)
          return if check_enum(value, [0, 1], "video full range flag")

          add_error("invalid video full range flag: #{value} (must be 0 or 1)")
        end

        def check_conflicts
          check_iccp_conflict
          check_srgb_conflict
        end

        def check_iccp_conflict
          return unless context.seen?("iCCP")

          add_warning(
            "cICP should not coexist with iCCP " \
            "(both specify color space information)",
          )
        end

        def check_srgb_conflict
          return unless context.seen?("sRGB")

          add_warning(
            "cICP should not coexist with sRGB " \
            "(both specify color space information)",
          )
        end

        def rgb_color?
          color_type = context.retrieve(:color_type)
          return false unless color_type

          # RGB (2) or RGB with alpha (6)
          [2, 6].include?(color_type)
        end
      end
    end
  end
end
