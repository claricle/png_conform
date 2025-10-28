# frozen_string_literal: true

require "bindata"
require_relative "chunk_structure"

module PngConform
  module BinData
    # Binary structure for PNG files
    #
    # PNG file format (from PNG spec):
    #   Signature: 8 bytes (0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A)
    #   Chunks:    variable number of chunks until IEND
    #
    # The PNG signature is always:
    #   - 0x89: High bit set to detect transmission as text
    #   - "PNG": Format identifier
    #   - 0x0D 0x0A: DOS-style line ending (CRLF)
    #   - 0x1A: DOS end-of-file character
    #   - 0x0A: Unix-style line ending (LF)
    #
    # @example Reading a PNG file
    #   File.open("image.png", "rb") do |f|
    #     png = PngFile.read(f)
    #     puts "Valid PNG" if png.valid_signature?
    #     png.chunks.each { |chunk| puts chunk.type }
    #   end
    #
    class PngFile < ::BinData::Record
      # PNG signature (8 bytes)
      # Must be: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
      string :signature, length: 8

      # Array of chunks (read until IEND)
      array :chunks, type: :chunk_structure, read_until: :eof

      # Expected PNG signature bytes
      PNG_SIGNATURE = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        .pack("C*")
        .freeze

      # Check if the signature is valid
      #
      # @return [Boolean] true if signature matches PNG specification
      def valid_signature?
        signature == PNG_SIGNATURE
      end

      # Get signature as hex string for debugging
      #
      # @return [String] signature in hex format
      def signature_hex
        signature.bytes.map { |b| format("%02x", b) }.join(" ")
      end

      # Find a specific chunk by type
      #
      # @param type [String, Symbol] chunk type (e.g., "IHDR" or :IHDR)
      # @return [ChunkStructure, nil] the first matching chunk or nil
      def find_chunk(type)
        type_str = type.to_s
        chunks.find { |chunk| chunk.type == type_str }
      end

      # Find all chunks of a specific type
      #
      # @param type [String, Symbol] chunk type
      # @return [Array<ChunkStructure>] all matching chunks
      def find_chunks(type)
        type_str = type.to_s
        chunks.select { |chunk| chunk.type == type_str }
      end

      # Get the IHDR chunk (image header)
      #
      # @return [ChunkStructure, nil] the IHDR chunk
      def ihdr
        find_chunk("IHDR")
      end

      # Get the IEND chunk (image end)
      #
      # @return [ChunkStructure, nil] the IEND chunk
      def iend
        find_chunk("IEND")
      end

      # Get all IDAT chunks (image data)
      #
      # @return [Array<ChunkStructure>] all IDAT chunks
      def idats
        find_chunks("IDAT")
      end

      # Get the PLTE chunk (palette)
      #
      # @return [ChunkStructure, nil] the PLTE chunk
      def plte
        find_chunk("PLTE")
      end

      # Check if this appears to be a valid PNG structure
      #
      # Basic validation:
      # - Valid signature
      # - Has IHDR as first chunk
      # - Has IEND as last chunk
      #
      # @return [Boolean] true if basic structure is valid
      def structurally_valid?
        return false unless valid_signature?
        return false if chunks.empty?
        return false unless chunks.first.type == "IHDR"
        return false unless chunks.last.type == "IEND"

        true
      end

      # Get chunk sequence as array of types
      #
      # @return [Array<String>] array of chunk type codes
      def chunk_sequence
        chunks.map(&:type)
      end

      # Count chunks by type
      #
      # @return [Hash<String, Integer>] chunk types and their counts
      def chunk_counts
        chunks.each_with_object(Hash.new(0)) do |chunk, counts|
          counts[chunk.type] += 1
        end
      end

      # Check if all chunks have valid CRCs
      #
      # @return [Boolean] true if all CRCs are valid
      def all_crcs_valid?
        chunks.all?(&:crc_valid?)
      end

      # Get chunks with invalid CRCs
      #
      # @return [Array<ChunkStructure>] chunks with CRC errors
      def invalid_crc_chunks
        chunks.reject(&:crc_valid?)
      end

      # Get file summary information
      #
      # @return [Hash] summary of file structure
      def summary
        {
          signature_valid: valid_signature?,
          chunk_count: chunks.length,
          chunk_types: chunk_counts,
          structurally_valid: structurally_valid?,
          all_crcs_valid: all_crcs_valid?,
        }
      end
    end
  end
end
