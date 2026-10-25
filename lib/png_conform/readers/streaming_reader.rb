# frozen_string_literal: true

require_relative "../bindata/chunk_structure"
require_relative "format_dispatch"
require_relative "chunk_framing"

module PngConform
  module Readers
    # Memory-efficient chunk-by-chunk PNG reader
    #
    # This reader processes PNG files one chunk at a time, making it suitable
    # for large files where loading the entire file into memory would be
    # impractical.
    #
    # @example Reading chunks one at a time
    #   File.open("large.png", "rb") do |f|
    #     reader = StreamingReader.new(f)
    #
    #     if reader.valid_signature?
    #       reader.each_chunk do |chunk|
    #         puts "#{chunk.type}: #{chunk.length} bytes"
    #       end
    #     end
    #   end
    #
    class StreamingReader
      # PNG signature (8 bytes)
      PNG_SIGNATURE = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        .pack("C*")
        .freeze

      attr_reader :io, :signature, :format, :total_bytes_read, :framing_error

      # Initialize a new streaming reader
      #
      # @param io [IO] IO object to read from (must be opened in binary mode)
      # @param options [Hash] Options for reading behavior
      # @option options [Boolean] :validate_crc (true) Calculate CRC during reading
      def initialize(io, options = {})
        @io = io
        @signature = nil
        @format = nil
        @chunks_read = 0
        @total_bytes_read = 0
        @framing_error = nil
        @validate_crc = options.fetch(:validate_crc, true)
      end

      # Read and validate the PNG signature
      #
      # This must be called before reading chunks.
      #
      # @return [Boolean] true if signature is valid
      def read_signature
        @signature = @io.read(8)
        @format = FormatDispatch.detect(@signature)
        valid_signature?
      end

      # Check if the signature is valid
      #
      # @return [Boolean] true if the signature is a PNG, MNG or JNG signature
      def valid_signature?
        !@format.nil?
      end

      # Get signature as hex string for debugging
      #
      # @return [String, nil] signature in hex format, or nil if not read
      def signature_hex
        return nil unless @signature

        @signature.bytes.map { |b| format("%02x", b) }.join(" ")
      end

      # Read the next chunk from the stream
      #
      # A chunk whose declared length exceeds the format limit or the
      # remaining bytes ends the stream and is recorded in #framing_error;
      # nothing is allocated for it.
      #
      # @return [BinData::ChunkStructure, nil] the next chunk, or nil if EOF
      def read_chunk
        return nil if @framing_error || @io.eof?

        @framing_error = ChunkFraming.check(@io, @chunks_read)
        return nil if @framing_error

        source_offset = @io.pos
        chunk = BinData::ChunkStructure.read(@io)
        chunk.source_offset = source_offset

        # Track total bytes read (8 byte header + data + 4 byte CRC)
        @total_bytes_read += (12 + chunk.data_length)

        # Validate CRC during reading if enabled and cache result
        if @validate_crc
          chunk.instance_variable_set(:@_crc_valid, chunk.crc_valid?)
        end

        @chunks_read += 1
        chunk
      rescue EOFError
        nil
      end

      # Iterate over all chunks in the file
      #
      # @yield [chunk] Each chunk in the file
      # @yieldparam chunk [BinData::ChunkStructure] the current chunk
      # @return [Integer] number of chunks read
      def each_chunk
        return enum_for(:each_chunk) unless block_given?

        # The outer terminator: MEND for MNG (an embedded IEND does not end
        # the stream), IEND for PNG and JNG. An unrecognized signature keeps
        # the historical IEND stop.
        terminator = (@format || FormatDispatch::PNG).terminator
        while (chunk = read_chunk)
          yield chunk
          break if chunk.type == terminator
        end

        @chunks_read
      end

      # Read all chunks into an array
      #
      # Note: This defeats the purpose of streaming for large files.
      # Use only when you need random access to chunks.
      #
      # @return [Array<BinData::ChunkStructure>] all chunks
      def read_all_chunks
        chunks = []
        each_chunk { |chunk| chunks << chunk }
        chunks
      end

      # Find the first chunk of a specific type
      #
      # @param type [String] chunk type to find
      # @return [BinData::ChunkStructure, nil] the first matching chunk
      def find_chunk(type)
        each_chunk do |chunk|
          return chunk if chunk.type == type
        end
        nil
      end

      # Collect all chunks of a specific type
      #
      # @param type [String] chunk type to find
      # @return [Array<BinData::ChunkStructure>] all matching chunks
      def find_chunks(type)
        chunks = []
        each_chunk do |chunk|
          chunks << chunk if chunk.type == type
        end
        chunks
      end

      # Reset the reader to the beginning of the file
      #
      # @return [void]
      def rewind
        @io.rewind
        @signature = nil
        @format = nil
        @chunks_read = 0
        @total_bytes_read = 0
        @framing_error = nil
      end

      # Get file size from total bytes tracked during reading
      #
      # Returns the total file size including signature and all chunks.
      # This is cached during reading to avoid O(n) recalculation.
      #
      # @return [Integer] File size in bytes (0 if no chunks read yet)
      def file_size
        # 8 bytes signature + total chunk bytes
        8 + @total_bytes_read
      end

      # Get the current position in the file
      #
      # @return [Integer] current byte position
      def position
        @io.pos
      end

      # Check if we've reached end of file
      #
      # @return [Boolean] true if at EOF
      def eof?
        @io.eof?
      end

      # Get statistics about the reading process
      #
      # @return [Hash] reading statistics
      def stats
        {
          chunks_read: @chunks_read,
          current_position: position,
          eof: eof?,
        }
      end

      # Read file from path using streaming reader
      #
      # @param path [String] path to PNG file
      # @yield [reader] The streaming reader
      # @yieldparam reader [StreamingReader] the reader instance
      # @return [Object] result of the block
      def self.open(path)
        File.open(path, "rb") do |f|
          reader = new(f)
          reader.read_signature
          yield reader
        end
      end
    end
  end
end
