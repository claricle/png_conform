# frozen_string_literal: true

require "bindata"

module PngConform
  module BinData
    # Base structure for PNG chunks
    #
    # PNG chunk format (from PNG spec):
    #   Length: 4 bytes (big-endian unsigned integer)
    #   Type:   4 bytes (4 ASCII characters)
    #   Data:   variable length (specified by Length field)
    #   CRC:    4 bytes (CRC-32 of Type and Data)
    #
    # @example Reading a chunk
    #   chunk = ChunkStructure.read(io)
    #   puts chunk.type        # => "IHDR"
    #   puts chunk.length      # => 13
    #   puts chunk.data.length # => 13
    #   puts chunk.crc         # => 0x9a76a1ae
    #
    class ChunkStructure < ::BinData::Record
      endian :big

      # Length of the data field (4 bytes, big-endian)
      uint32 :data_length

      # Chunk type code (4 bytes, ASCII)
      string :chunk_type, length: 4

      # Chunk data (variable length, specified by data_length field)
      string :chunk_data, read_length: :data_length

      # CRC-32 checksum (4 bytes, big-endian)
      # CRC is calculated over the Type and Data fields
      uint32 :crc

      # Convenience accessor for chunk type
      #
      # @return [String] chunk type code
      def type
        chunk_type
      end

      # Convenience accessor for chunk data
      #
      # @return [String] chunk data
      def data
        chunk_data
      end

      # Convenience accessor for data length
      #
      # @return [Integer] data length
      def length
        data_length
      end

      # Calculate the expected CRC-32 value
      #
      # The CRC is calculated over the chunk type and data fields.
      # This uses the standard CRC-32 algorithm as specified in PNG spec.
      #
      # @return [Integer] the calculated CRC-32 value
      def calculated_crc
        require "zlib"
        ::Zlib.crc32(chunk_type + chunk_data)
      end

      # Check if the stored CRC matches the calculated CRC
      #
      # @return [Boolean] true if CRC is valid, false otherwise
      def crc_valid?
        crc == calculated_crc
      end

      # Get chunk type as a symbol for easier matching
      #
      # @return [Symbol] chunk type as symbol (e.g., :IHDR)
      def type_symbol
        chunk_type.to_sym
      end

      # Check if this is a critical chunk
      #
      # Critical chunks have uppercase first letter in type code.
      # From PNG spec: bit 5 of first byte is 0 for critical chunks.
      #
      # @return [Boolean] true if critical chunk
      def critical?
        (chunk_type[0].ord & 0x20).zero?
      end

      # Check if this is an ancillary chunk
      #
      # Ancillary chunks have lowercase first letter in type code.
      #
      # @return [Boolean] true if ancillary chunk
      def ancillary?
        !critical?
      end

      # Check if this chunk is safe to copy
      #
      # Safe-to-copy chunks have lowercase fourth letter.
      # From PNG spec: bit 5 of fourth byte is 1 for safe-to-copy.
      #
      # @return [Boolean] true if safe to copy
      def safe_to_copy?
        chunk_type[3].ord & 0x20 != 0
      end

      # Check if this is a private chunk
      #
      # Private chunks have lowercase second letter.
      # From PNG spec: bit 5 of second byte is 1 for private chunks.
      #
      # @return [Boolean] true if private chunk
      def private?
        chunk_type[1].ord & 0x20 != 0
      end

      # Get human-readable chunk information
      #
      # @return [String] formatted chunk information
      def to_s
        format(
          "%s: %d bytes (CRC: 0x%08x %s)",
          chunk_type,
          data_length,
          crc,
          crc_valid? ? "OK" : "INVALID",
        )
      end

      # Get detailed chunk information for debugging
      #
      # @return [Hash] chunk details
      def inspect_details
        {
          type: chunk_type,
          length: data_length,
          data_size: chunk_data.length,
          crc: format("0x%08x", crc),
          crc_valid: crc_valid?,
          critical: critical?,
          private: private?,
          safe_to_copy: safe_to_copy?,
        }
      end
    end
  end
end
