# frozen_string_literal: true

require_relative "../models/validation_result"
require_relative "../models/file_analysis"
require_relative "../models/image_info"
require_relative "../models/compression_info"

module PngConform
  module Services
    # Builds validation results and file analysis
    #
    # The ResultBuilder handles:
    # - Building ValidationResult from validation context
    # - Extracting ImageInfo from IHDR chunk
    # - Extracting CompressionInfo (lazy calculation)
    # - Building complete FileAnalysis model
    #
    # This class extracts result building logic from ValidationService
    # following Single Responsibility Principle.
    #
    class ResultBuilder
      # Initialize result builder
      #
      # @param reader [Object] File reader (StreamingReader or FullLoadReader)
      # @param filepath [String] File path for reporting
      # @param context [ValidationContext] Validation context with results
      # @param chunks [Array] Array of BinData chunks
      # @param options [Hash] CLI options for conditional calculations
      def initialize(reader, filepath, context, chunks, options = {})
        @reader = reader
        @filepath = filepath
        @context = context
        @chunks = chunks
        @options = options
        @idat_data_cache = nil # Cache for streaming IDAT data
      end

      # Build complete FileAnalysis with all data
      #
      # @return [FileAnalysis] Complete analysis model
      def build
        # First build the ValidationResult
        validation_result = build_validation_result

        # Extract image info from IHDR
        image_info = extract_image_info(validation_result)

        # Build complete FileAnalysis
        Models::FileAnalysis.new.tap do |analysis|
          analysis.file_path = @filepath || "unknown"
          analysis.file_size = validation_result.file_size
          analysis.file_type = validation_result.file_type
          analysis.validation_result = validation_result
          analysis.image_info = image_info
          analysis.compression_info = extract_compression_info(validation_result)
        end
      end

      private

      # Build ValidationResult from validation context and chunks
      #
      # @return [ValidationResult] Validation results with chunks and errors
      def build_validation_result
        Models::ValidationResult.new.tap do |result|
          # Set file metadata
          result.filename = @filepath || "unknown"
          result.file_type = determine_file_type
          result.file_size = calculate_file_size

          # Add all chunks with CRC validation
          add_chunks_with_crc(result)

          # Calculate compression ratio for PNG files (lazy calculation)
          result.compression_ratio = if result.file_type == "PNG" &&
              need_compression_ratio?
                                       calculate_compression_ratio(result.chunks)
                                     else
                                       0.0
                                     end

          # Add all errors, warnings, and info from context
          add_context_messages(result)
        end
      end

      # Add chunks with CRC validation to result
      #
      # Caches IDAT data during initial pass for streaming compression calculation.
      # Uses cached CRC validation from reader if available to avoid recalculation.
      #
      # @param result [ValidationResult] Result to add chunks to
      # @return [void]
      def add_chunks_with_crc(result)
        crc_error_count = 0

        @chunks.each do |bindata_chunk|
          chunk = Models::Chunk.from_bindata(bindata_chunk,
                                             bindata_chunk.abs_offset)

          # Cache IDAT data for streaming compression calculation
          if bindata_chunk.chunk_type.to_s == "IDAT"
            @idat_data_cache ||= ""
            @idat_data_cache += bindata_chunk.data.to_s
          end

          # Validate CRC using cached result if available
          expected_crc = bindata_chunk.crc
          chunk.crc_expected = format_hex(expected_crc)

          # Check if reader already validated CRC (cached in @_crc_valid)
          if bindata_chunk.instance_variable_defined?(:@_crc_valid)
            # Use cached validation result
            chunk.valid_crc = bindata_chunk.instance_variable_get(:@_crc_valid)
            # Don't set crc_actual since we didn't recalculate it
          else
            # Calculate CRC if not cached
            actual_crc = calculate_crc(bindata_chunk)
            chunk.crc_actual = format_hex(actual_crc)
            chunk.valid_crc = (expected_crc == actual_crc)
          end

          crc_error_count += 1 unless chunk.valid_crc

          result.add_chunk(chunk)
        end

        result.crc_errors_count = crc_error_count
      end

      # Add all messages from validation context to result
      #
      # @param result [ValidationResult] Result to add messages to
      # @return [void]
      def add_context_messages(result)
        # Add errors from context
        @context.all_errors.each do |e|
          result.error(e[:message])
        end

        # Add warnings from context
        @context.all_warnings.each do |w|
          result.warning(w[:message])
        end

        # Add info from context
        @context.all_info.each do |i|
          result.info(i[:message])
        end
      end

      # Calculate file size from reader or chunks
      #
      # Performance optimization: Use reader.file_size if available,
      # otherwise calculate from chunks (O(n) operation).
      #
      # @return [Integer] File size in bytes
      def calculate_file_size
        if @reader.respond_to?(:file_size)
          @reader.file_size
        else
          # 8 bytes signature + sum of chunk sizes
          # (8 byte header + data + 4 byte CRC per chunk)
          8 + @chunks.sum { |c| 12 + c.length }
        end
      end

      # Determine file type based on chunks
      #
      # @return [String] File type (PNG, MNG, JNG, or UNKNOWN)
      def determine_file_type
        return Models::ValidationResult::FILE_TYPE_MNG if @context.seen?("MHDR")
        return Models::ValidationResult::FILE_TYPE_JNG if @context.seen?("JHDR")
        return Models::ValidationResult::FILE_TYPE_PNG if @context.seen?("IHDR")

        Models::ValidationResult::FILE_TYPE_UNKNOWN
      end

      # Calculate CRC32 for a chunk
      #
      # @param chunk [Object] BinData chunk
      # @return [Integer] CRC32 value
      def calculate_crc(chunk)
        require "zlib"
        # CRC is calculated over chunk type + chunk data
        Zlib.crc32(chunk.chunk_type.to_s + chunk.data.to_s)
      end

      # Format integer as hex string
      #
      # @param value [Integer] Value to format
      # @return [String] Hex string (e.g., "0x12345678")
      def format_hex(value)
        format("0x%08x", value)
      end

      # Calculate compression ratio for PNG
      #
      # Streaming optimization: Uses cached IDAT data from initial chunk read
      # to avoid re-selecting and concatenating chunks.
      #
      # Lazy calculation - only performed when needed.
      #
      # @param chunks [Array<Chunk>] All chunks
      # @return [Float] Compression ratio as percentage, 0.0 if cannot calculate
      def calculate_compression_ratio(chunks)
        # Use cached IDAT data from streaming read
        idat_chunks = chunks.select { |c| c.type == "IDAT" }
        return 0.0 if idat_chunks.empty?

        compressed_size = idat_chunks.sum(&:length)
        return 0.0 if compressed_size.zero?

        # Try to decompress to get original size
        begin
          require "zlib"

          # Use cached IDAT data from initial read (streaming optimization)
          compressed_data = @idat_data_cache || ""

          decompressed = Zlib::Inflate.inflate(compressed_data)
          original_size = decompressed.bytesize

          return 0.0 if original_size.zero?

          # Calculate percentage: (compressed/original - 1) * 100
          # Negative means compression, positive means expansion
          (((compressed_size.to_f / original_size) - 1) * 100).round(1)
        rescue StandardError
          # If decompression fails, we can't calculate ratio
          0.0
        end
      end

      # Extract ImageInfo from IHDR chunk
      #
      # @param result [ValidationResult] Validation result with chunks
      # @return [ImageInfo, nil] Image info or nil if IHDR not found
      def extract_image_info(result)
        ihdr = result.ihdr_chunk
        return nil unless ihdr&.data && ihdr.data.bytesize >= 13

        width = ihdr.data.bytes[0..3].pack("C*").unpack1("N")
        height = ihdr.data.bytes[4..7].pack("C*").unpack1("N")
        bit_depth = ihdr.data.bytes[8]
        color_type = ihdr.data.bytes[9]
        interlace = ihdr.data.bytes[12]

        Models::ImageInfo.new.tap do |info|
          info.width = width
          info.height = height
          info.bit_depth = bit_depth
          info.color_type = color_type_name(color_type)
          info.interlaced = interlace == 1
          info.animated = false # Could check for APNG chunks
        end
      end

      # Extract CompressionInfo
      #
      # @param result [ValidationResult] Validation result
      # @return [CompressionInfo, nil] Compression info or nil
      def extract_compression_info(result)
        return nil unless result.compression_ratio

        Models::CompressionInfo.new.tap do |info|
          info.compression_ratio = result.compression_ratio
          info.compressed_size = result.chunks.select do |c|
            c.type == "IDAT"
          end.sum(&:length)
        end
      end

      # Helper to convert color type code to name
      #
      # @param code [Integer] Color type code
      # @return [String] Color type name
      def color_type_name(code)
        case code
        when 0 then "grayscale"
        when 2 then "truecolor"
        when 3 then "palette"
        when 4 then "grayscale+alpha"
        when 6 then "truecolor+alpha"
        else "unknown"
        end
      end

      # Check if compression ratio calculation is needed
      #
      # @return [Boolean] True if compression ratio should be calculated
      def need_compression_ratio?
        return true if ["yaml", "json"].include?(@options[:format])

        !@options[:quiet]
      end
    end
  end
end
