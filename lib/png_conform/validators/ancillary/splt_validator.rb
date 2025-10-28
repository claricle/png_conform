# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    module Ancillary
      # Validator for PNG sPLT (Suggested Palette) chunk
      #
      # sPLT suggests a reduced palette for quantization:
      # - Palette name (1-79 bytes, Latin-1)
      # - Null separator (1 byte)
      # - Sample depth (1 byte, 8 or 16)
      # - Palette entries (6 or 10 bytes each):
      #   * Red (1 or 2 bytes)
      #   * Green (1 or 2 bytes)
      #   * Blue (1 or 2 bytes)
      #   * Alpha (1 or 2 bytes)
      #   * Frequency (2 bytes)
      #
      # Validation rules from PNG spec:
      # - Palette name must be 1-79 characters, Latin-1 printable
      # - Palette name must not have leading/trailing/consecutive spaces
      # - Sample depth must be 8 or 16
      # - Number of entries must be exact (no partial entries)
      # - Must appear before IDAT chunk
      # - Multiple sPLT chunks allowed with different names
      class SpltValidator < BaseValidator
        # Maximum palette name length
        MAX_PALETTE_NAME_LENGTH = 79

        # Latin-1 printable characters (space to tilde + high ASCII)
        PRINTABLE_LATIN1 = (32..126).to_a + (161..255).to_a

        # Valid sample depths
        VALID_SAMPLE_DEPTHS = [8, 16].freeze

        # Entry sizes by sample depth
        ENTRY_SIZE_8BIT = 6 # RGBA (1 byte each) + frequency (2 bytes)
        ENTRY_SIZE_16BIT = 10 # RGBA (2 bytes each) + frequency (2 bytes)

        # Validate sPLT chunk
        #
        # @return [Boolean] True if validation passed
        def validate
          return false unless check_crc
          return false unless check_position
          return false unless check_structure
          return false unless check_palette_name
          return false unless check_sample_depth
          return false unless check_entries

          store_palette_info
          true
        end

        private

        # Check that sPLT appears before IDAT
        def check_position
          if context.seen?("IDAT")
            add_error("sPLT chunk after IDAT chunk")
            return false
          end

          true
        end

        # Check sPLT chunk structure
        def check_structure
          data = chunk.chunk_data

          # Must contain at least name + null + sample depth
          if data.length < 3
            add_error("sPLT chunk too short (minimum 3 bytes)")
            return false
          end

          # Must contain null separator
          null_pos = data.index("\0")
          unless null_pos
            add_error("sPLT chunk missing null separator")
            return false
          end

          true
        end

        # Check palette name validity
        def check_palette_name
          data = chunk.chunk_data
          null_pos = data.index("\0")
          palette_name = data[0, null_pos]

          # Check palette name length
          if palette_name.empty?
            add_error("sPLT chunk has empty palette name")
            return false
          end

          if palette_name.length > MAX_PALETTE_NAME_LENGTH
            add_error("sPLT palette name too long (#{palette_name.length}, " \
                      "max #{MAX_PALETTE_NAME_LENGTH})")
            return false
          end

          # Check for Latin-1 printable characters
          palette_name.bytes.each do |byte|
            next if PRINTABLE_LATIN1.include?(byte)

            add_error("sPLT palette name contains non-printable " \
                      "character (0x#{byte.to_s(16)})")
            return false
          end

          # Check for leading/trailing spaces
          if palette_name.start_with?(" ")
            add_error("sPLT palette name has leading space")
            return false
          end

          if palette_name.end_with?(" ")
            add_error("sPLT palette name has trailing space")
            return false
          end

          # Check for consecutive spaces
          if palette_name.include?("  ")
            add_error("sPLT palette name has consecutive spaces")
            return false
          end

          true
        end

        # Check sample depth
        def check_sample_depth
          data = chunk.chunk_data
          null_pos = data.index("\0")
          sample_depth = data[null_pos + 1].ord

          unless VALID_SAMPLE_DEPTHS.include?(sample_depth)
            add_error("sPLT invalid sample depth (#{sample_depth}, " \
                      "must be 8 or 16)")
            return false
          end

          true
        end

        # Check palette entries
        def check_entries
          data = chunk.chunk_data
          null_pos = data.index("\0")
          sample_depth = data[null_pos + 1].ord
          entries_data = data[(null_pos + 2)..] || ""

          # Determine entry size
          entry_size = sample_depth == 8 ? ENTRY_SIZE_8BIT : ENTRY_SIZE_16BIT

          # Check that entries data is exact multiple of entry size
          if (entries_data.length % entry_size) != 0
            add_error("sPLT entries data length (#{entries_data.length}) " \
                      "not a multiple of entry size (#{entry_size})")
            return false
          end

          # Check minimum entries (at least 1)
          num_entries = entries_data.length / entry_size
          if num_entries.zero?
            add_error("sPLT chunk has no palette entries")
            return false
          end

          true
        end

        # Store suggested palette information in context
        def store_palette_info
          data = chunk.chunk_data
          null_pos = data.index("\0")
          palette_name = data[0, null_pos]
          sample_depth = data[null_pos + 1].ord
          entries_data = data[(null_pos + 2)..] || ""

          # Calculate number of entries
          entry_size = sample_depth == 8 ? ENTRY_SIZE_8BIT : ENTRY_SIZE_16BIT
          num_entries = entries_data.length / entry_size

          # Parse entries and find frequency range
          frequencies = []
          (0...num_entries).each do |i|
            offset = i * entry_size
            freq_offset = offset + (entry_size - 2)
            freq = (entries_data[freq_offset].ord << 8) |
              entries_data[freq_offset + 1].ord
            frequencies << freq
          end

          # Store in context (allow multiple sPLT chunks)
          palettes = context.retrieve(:suggested_palettes) || []
          palettes << {
            name: palette_name,
            sample_depth: sample_depth,
            num_entries: num_entries,
            frequencies: frequencies,
          }
          context.store(:suggested_palettes, palettes)

          # Add info about the suggested palette
          max_freq = frequencies.max || 0
          min_freq = frequencies.min || 0
          total_freq = frequencies.sum

          add_info("sPLT: \"#{palette_name}\" " \
                   "(#{num_entries} entries, #{sample_depth}-bit, " \
                   "frequency range #{min_freq}-#{max_freq}, " \
                   "total #{total_freq})")
        end
      end
    end
  end
end
