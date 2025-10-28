# frozen_string_literal: true

module PngConform
  module BinData
    # MNG (Multiple-image Network Graphics) file structure
    # An MNG file consists of:
    # - 8-byte signature: 138 77 78 71 13 10 26 10
    # - MHDR chunk (must be first)
    # - Series of chunks (can include PNG chunks)
    # - MEND chunk (must be last)
    class MngFile < ::BinData::Record
      # MNG signature (magic number)
      MNG_SIGNATURE = [138, 77, 78, 71, 13, 10, 26, 10].pack("C*").freeze

      string :signature, length: 8
      array :chunks, type: :chunk_structure, read_until: :eof

      # Validate MNG signature
      def valid_signature?
        signature == MNG_SIGNATURE
      end

      # Get signature as hex string for display
      def signature_hex
        signature.unpack1("H*")
      end

      # Find chunks by type
      def chunks_by_type(type)
        chunks.select { |chunk| chunk.type == type }
      end

      # Get MHDR chunk (must be first chunk)
      def mhdr_chunk
        chunks.first if chunks.first&.type == "MHDR"
      end

      # Get MEND chunk (must be last chunk)
      def mend_chunk
        chunks.last if chunks.last&.type == "MEND"
      end

      # Get all PNG image chunks (IHDR-IEND sequences)
      def png_images
        images = []
        current_image = []

        chunks.each do |chunk|
          if chunk.type == "IHDR"
            current_image = [chunk]
          elsif !current_image.empty?
            current_image << chunk
            if chunk.type == "IEND"
              images << current_image
              current_image = []
            end
          end
        end

        images
      end

      # Get all JNG image chunks (JHDR-IEND sequences)
      def jng_images
        images = []
        current_image = []

        chunks.each do |chunk|
          if chunk.type == "JHDR"
            current_image = [chunk]
          elsif !current_image.empty?
            current_image << chunk
            if chunk.type == "IEND"
              images << current_image
              current_image = []
            end
          end
        end

        images
      end

      # Check if file has proper chunk ordering
      def proper_chunk_order?
        return false unless mhdr_chunk
        return false unless mend_chunk

        true
      end

      # Get total file size
      def total_size
        8 + chunks.sum(&:total_size)
      end
    end
  end
end
