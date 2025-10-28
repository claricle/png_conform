# frozen_string_literal: true

require_relative "../validators/chunk_registry"
require_relative "../models/validation_result"

module PngConform
  module Services
    # Main validation orchestration service
    #
    # This service coordinates the validation of PNG files by:
    # 1. Reading chunks from the file
    # 2. Creating appropriate validators for each chunk
    # 3. Executing validation in the correct order
    # 4. Collecting and aggregating results
    #
    # The service follows a pipeline architecture:
    # File → Chunks → Validators → Results
    #
    class ValidationService
      attr_reader :reader, :context, :results, :chunks

      # Convenience method to validate a file by path
      #
      # @param filepath [String] Path to PNG file
      # @return [ValidationResult] Validation results
      def self.validate_file(filepath)
        require_relative "../readers/full_load_reader"
        reader = Readers::FullLoadReader.new(filepath)
        service = new(reader, filepath)
        service.validate
      end

      # Initialize validation service
      #
      # @param reader [Object] File reader (StreamingReader or FullLoadReader)
      # @param filepath [String, nil] Optional file path (for reporting)
      def initialize(reader, filepath = nil)
        @reader = reader
        @filepath = filepath
        @context = Validators::ValidationContext.new
        @results = []
        @chunks = [] # Store chunks as we read them
      end

      # Validate the PNG file
      #
      # This is the main entry point for validation. It processes all chunks
      # in order, validates them, and collects the results.
      #
      # @return [ValidationResult] Aggregated validation results
      def validate
        validate_signature
        validate_chunks
        validate_chunk_sequence
        build_result
      end

      # Validate PNG signature
      #
      # Checks that the file starts with the PNG signature:
      # 137 80 78 71 13 10 26 10
      #
      # @return [void]
      def validate_signature
        sig = reader.signature
        expected = [137, 80, 78, 71, 13, 10, 26, 10].pack("C*")

        return if sig == expected

        add_error("Invalid PNG signature")
      end

      # Validate all chunks in the file
      #
      # Processes each chunk in order:
      # 1. Check for validator
      # 2. Create validator instance
      # 3. Execute validation
      # 4. Collect results
      #
      # @return [void]
      def validate_chunks
        reader.each_chunk do |chunk|
          @chunks << chunk # Store chunk for later use
          validate_chunk(chunk)
        end
      end

      # Validate a single chunk
      #
      # @param chunk [Object] Chunk to validate
      # @return [void]
      def validate_chunk(chunk)
        # Get validator for this chunk type
        validator = Validators::ChunkRegistry.create_validator(chunk, context)

        if validator
          # Validate chunk with registered validator
          validator.validate
          # Errors are stored in context, not validator
        else
          # Unknown chunk - check if it's safe to ignore
          handle_unknown_chunk(chunk)
        end

        # Mark chunk as seen AFTER validation
        # This allows validators to check for duplicates before marking
        # Convert BinData::String to regular String for hash key consistency
        context.mark_chunk_seen(chunk.chunk_type.to_s, chunk)
      end

      # Handle unknown chunk types
      #
      # Unknown chunks are checked for safety:
      # - If ancillary (bit 5 of first byte = 1), it's safe to ignore
      # - If critical (bit 5 = 0), it's an error
      #
      # @param chunk [Object] Unknown chunk
      # @return [void]
      def handle_unknown_chunk(chunk)
        # Convert BinData::String to regular String
        chunk_type = chunk.chunk_type.to_s
        first_byte = chunk_type.bytes[0]

        # Bit 5 (0x20) of first byte indicates ancillary vs critical
        if (first_byte & 0x20).zero?
          # Critical chunk - must be recognized
          add_error("Unknown critical chunk type: #{chunk_type}")
        else
          # Ancillary chunk - safe to ignore
          add_info("Unknown ancillary chunk type: #{chunk_type} (ignored)")
        end
      end

      # Validate chunk sequence requirements
      #
      # Checks high-level sequencing rules:
      # - IHDR must be first chunk
      # - IEND must be last chunk
      # - At least one IDAT chunk required
      #
      # @return [void]
      def validate_chunk_sequence
        validate_ihdr_first
        validate_iend_last
        validate_idat_present
      end

      # Check that IHDR is the first chunk
      #
      # @return [void]
      def validate_ihdr_first
        return if context.seen?("IHDR")

        add_error("Missing IHDR chunk (must be first)")
      end

      # Check that IEND is the last chunk
      #
      # @return [void]
      def validate_iend_last
        return if context.seen?("IEND")

        add_error("Missing IEND chunk (must be last)")
      end

      # Check that at least one IDAT chunk exists
      #
      # @return [void]
      def validate_idat_present
        return if context.seen?("IDAT")

        add_error("Missing IDAT chunk (at least one required)")
      end

      # Build final validation result
      #
      # Aggregates errors from two sources:
      # 1. @results - errors added directly by ValidationService
      # 2. context - errors added by validators during validation
      #
      # @return [ValidationResult] Aggregated results
      def build_result
        Models::ValidationResult.new.tap do |result|
          # Set file metadata
          result.filename = @filepath || "unknown"

          result.file_type = determine_file_type

          # Calculate file size from chunks if reader doesn't provide it
          result.file_size = if reader.respond_to?(:file_size)
                               reader.file_size
                             else
                               # 8 bytes signature + sum of chunk sizes (8 byte header + data + 4 byte CRC per chunk)
                               8 + @chunks.sum { |c| 12 + c.length }
                             end

          # Add all chunks with CRC validation
          crc_error_count = 0
          @chunks.each do |bindata_chunk|
            chunk = Models::Chunk.from_bindata(bindata_chunk,
                                               bindata_chunk.abs_offset)

            # Validate CRC
            expected_crc = bindata_chunk.crc
            actual_crc = calculate_crc(bindata_chunk)
            chunk.crc_expected = format_hex(expected_crc)
            chunk.crc_actual = format_hex(actual_crc)
            chunk.valid_crc = (expected_crc == actual_crc)

            crc_error_count += 1 unless chunk.valid_crc

            result.add_chunk(chunk)
          end

          result.crc_errors_count = crc_error_count

          # Calculate compression ratio for PNG files
          if result.file_type == "PNG"
            result.compression_ratio = calculate_compression_ratio(result.chunks)
          end

          # Add errors from service (@results)
          @results.select { |r| r[:type] == :error }.each do |r|
            result.error(r[:message])
          end

          # Add errors from validators (context)
          context.all_errors.each do |e|
            result.error(e[:message])
          end

          # Add warnings from service (@results)
          @results.select { |r| r[:type] == :warning }.each do |r|
            result.warning(r[:message])
          end

          # Add warnings from validators (context)
          context.all_warnings.each do |w|
            result.warning(w[:message])
          end

          # Add info from service (@results)
          @results.select { |r| r[:type] == :info }.each do |r|
            result.info(r[:message])
          end

          # Add info from validators (context)
          context.all_info.each do |i|
            result.info(i[:message])
          end
        end
      end

      private

      # Add an error to results
      #
      # @param message [String] Error message
      # @return [void]
      def add_error(message)
        @results << { type: :error, message: message }
      end

      # Add a warning to results
      #
      # @param message [String] Warning message
      # @return [void]
      def add_warning(message)
        @results << { type: :warning, message: message }
      end

      # Add info to results
      #
      # @param message [String] Info message
      # @return [void]
      def add_info(message)
        @results << { type: :info, message: message }
      end

      # Merge results from a validator
      #
      # @param errors [Array<String>] Error messages
      # @param warnings [Array<String>] Warning messages
      # @param info [Array<String>] Info messages
      # @return [void]
      def merge_results(errors, warnings, info)
        errors.each { |msg| add_error(msg) }
        warnings.each { |msg| add_warning(msg) }
        info.each { |msg| add_info(msg) }
      end

      # Determine file type based on chunks
      #
      # @return [String] File type (PNG, MNG, JNG, or UNKNOWN)
      def determine_file_type
        return Models::ValidationResult::FILE_TYPE_MNG if context.seen?("MHDR")
        return Models::ValidationResult::FILE_TYPE_JNG if context.seen?("JHDR")
        return Models::ValidationResult::FILE_TYPE_PNG if context.seen?("IHDR")

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
      # @param chunks [Array<Chunk>] All chunks
      # @return [Float] Compression ratio as percentage, 0.0 if cannot calculate
      def calculate_compression_ratio(chunks)
        idat_chunks = chunks.select { |c| c.type == "IDAT" }
        return 0.0 if idat_chunks.empty?

        compressed_size = idat_chunks.sum(&:length)
        return 0.0 if compressed_size.zero?

        # Try to decompress to get original size
        # Need to get actual binary data from BinData chunks, not Model chunks
        begin
          require "zlib"

          # Get IDAT chunks from the original BinData chunks
          idat_bindata = @chunks.select { |c| c.chunk_type.to_s == "IDAT" }
          compressed_data = idat_bindata.map { |c| c.data.to_s }.join

          decompressed = Zlib::Inflate.inflate(compressed_data)
          original_size = decompressed.bytesize

          return 0.0 if original_size.zero?

          # Calculate percentage: (compressed/original - 1) * 100
          # Negative means compression, positive means expansion
          ((compressed_size.to_f / original_size - 1) * 100).round(1)
        rescue StandardError
          # If decompression fails, we can't calculate ratio
          # Return 0.0 instead of nil so it appears in YAML/JSON
          0.0
        end
      end
    end
  end
end
