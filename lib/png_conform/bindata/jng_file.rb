# frozen_string_literal: true

module PngConform
  module BinData
    # JNG (JPEG Network Graphics) file structure
    # A JNG file consists of:
    # - 8-byte signature: 139 74 78 71 13 10 26 10
    # - JHDR chunk (must be first)
    # - JDAT chunks (JPEG data)
    # - Optional IDAT chunks (PNG alpha channel)
    # - IEND chunk (must be last)
    class JngFile < ::BinData::Record
      # JNG signature (magic number)
      JNG_SIGNATURE = [139, 74, 78, 71, 13, 10, 26, 10].pack("C*").freeze

      string :signature, length: 8
      array :chunks, type: :chunk_structure, read_until: :eof

      # Validate JNG signature
      def valid_signature?
        signature == JNG_SIGNATURE
      end

      # Get signature as hex string for display
      def signature_hex
        signature.unpack1("H*")
      end

      # Find chunks by type
      def chunks_by_type(type)
        chunks.select { |chunk| chunk.type == type }
      end

      # Get JHDR chunk (must be first chunk)
      def jhdr_chunk
        chunks.first if chunks.first&.type == "JHDR"
      end

      # Get IEND chunk (must be last chunk)
      def iend_chunk
        chunks.last if chunks.last&.type == "IEND"
      end

      # Get all JDAT chunks (JPEG image data)
      def jdat_chunks
        chunks_by_type("JDAT")
      end

      # Get all IDAT chunks (PNG alpha channel data)
      def idat_chunks
        chunks_by_type("IDAT")
      end

      # Get JSEP chunk (8/12-bit separator, if present)
      def jsep_chunk
        chunks_by_type("JSEP").first
      end

      # Check if JNG has alpha channel
      def has_alpha?
        !idat_chunks.empty?
      end

      # Check if file has proper chunk ordering
      def proper_chunk_order?
        return false unless jhdr_chunk
        return false unless iend_chunk
        return false if jdat_chunks.empty?

        true
      end

      # Get total file size
      def total_size
        8 + chunks.sum(&:total_size)
      end
    end
  end
end
