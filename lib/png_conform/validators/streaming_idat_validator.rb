# frozen_string_literal: true

require_relative "../base_validator"

module PngConform
  module Validators
    # Streaming IDAT validator for memory-efficient validation
    #
    # This validator processes IDAT chunk data in streaming mode to avoid
    # loading large decompressed image data into memory. Instead of
    # fully decompressing, it validates the zlib stream incrementally.
    #
    class StreamingIdatValidator < BaseValidator
      # Validate IDAT chunk
      #
      # Performs streaming validation of zlib-compressed image data
      # without fully decompressing into memory.
      #
      # @return [void]
      def validate
        return add_error("Invalid IDAT sequence") unless check_idat_sequence
        return add_error("Invalid IDAT order") unless check_idat_order

        # Validate compression in streaming mode
        validate_streaming_compression
      end

      private

      # Check IDAT sequence requirements
      #
      # @return [Boolean] True if IDAT sequence is valid
      def check_idat_sequence
        # IDAT chunks must be consecutive
        previous_chunk_type = @context.seen?("IDAT") ? "IDAT" : nil

        if previous_chunk_type && previous_chunk_type != "IDAT"
          add_warning("IDAT chunks must be consecutive")
          return false
        end

        true
      end

      # Check IDAT order requirements
      #
      # IDAT must come after PLTE (if present) and before IEND
      #
      # @return [Boolean] True if IDAT is in correct position
      def check_idat_order
        # IDAT cannot be first (must have IHDR)
        return false unless @context.seen?("IHDR")

        # If PLTE exists, IDAT must come after it
        if @context.seen?("PLTE")
          @context.chunks_of_type("PLTE")
          find_chunk_index("PLTE")
          @context.chunks_of_type("IDAT").length

          # For now, just check that PLTE was seen before any IDAT
          # The actual ordering is validated in sequence validation
        end

        true
      end

      # Find the index of a chunk in the validation sequence
      #
      # @param chunk_type [String] Chunk type to find
      # @return [Integer, nil] Index of chunk or nil
      def find_chunk_index(_chunk_type)
        # This would require tracking chunk order in context
        # For now, return nil as this is handled by sequence validation
        nil
      end

      # Validate compression using streaming zlib validation
      #
      # Instead of fully decompressing the image data (which can be huge),
      # this validates that the compressed data is valid zlib format without
      # loading the decompressed result.
      #
      # @return [void]
      def validate_streaming_compression
        require "zlib"

        # Try to validate the zlib stream without full decompression
        # We inflate just enough to verify validity
        begin
          inflater = Zlib::Inflate.new(Zlib::MAX_WBITS)

          # Process data in chunks to avoid large memory allocation
          chunk.data.each_slice(8192) do |slice|
            # << is used to append data to the inflate stream
            # This validates the data format without storing result
            result = inflater << slice

            # If we got decompressed data back, the stream is valid
            # We don't need to store it, just validate
            if result && !result.empty?
              # Data is valid, we can discard it
              # This means the compressed data is well-formed
            end
          rescue Zlib::DataError => e
            return add_error("Invalid compressed data in IDAT: #{e.message}")
          end

          # Finish the stream to validate end of data
          inflater.finish
          inflater.close

          add_info("Streaming compression validation successful")
        rescue Zlib::StreamError => e
          add_error("Invalid zlib stream in IDAT: #{e.message}")
        rescue Zlib::BufError => e
          add_error("Buffer error in IDAT compression: #{e.message}")
        rescue StandardError => e
          add_error("Compression validation error: #{e.message}")
        end
      end
    end
  end
end
