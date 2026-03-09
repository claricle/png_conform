# frozen_string_literal: true

require "digest"

module PngConform
  module Services
    # File signature service for fast comparison
    #
    # Creates cryptographic signatures of PNG files to enable fast
    # equality checking without full validation. This is particularly
    # useful for comparison operations and caching.
    #
    # The signature is based on key file characteristics that are
    # quick to compute but provide strong uniqueness guarantees.
    #
    class FileSignature
      attr_reader :result, :signature, :metadata

      class << self
        # Create signature from ValidationResult
        #
        # @param result [ValidationResult] Validation result to signature
        # @return [FileSignature] FileSignature instance
        def from_result(result)
          new(result).compute_signature
        end

        # Create signature directly from file metadata
        #
        # @param file_path [String] Path to PNG file
        # @param options [Hash] Options for signature creation
        # @return [FileSignature] FileSignature instance
        def from_file(file_path, _options = {})
          unless File.exist?(file_path)
            raise ArgumentError, "File not found: #{file_path}"
          end

          # Quick signature from file metadata without full validation
          metadata = extract_quick_metadata(file_path)
          new(nil, metadata).compute_signature
        end
      end

      # Initialize with validation result or metadata hash
      #
      # @param result [ValidationResult, nil] Validation result
      # @param metadata [Hash, nil] File metadata hash
      def initialize(result, metadata = nil)
        @result = result
        @metadata = metadata || extract_metadata_from_result
        @signature = nil
      end

      # Compute the signature
      #
      # @return [FileSignature] Self for chaining
      def compute_signature
        @signature = generate_signature
        self
      end

      # Check if two signatures are equal
      #
      # @param other [FileSignature, String] Another signature or signature string
      # @return [Boolean] True if signatures match
      def ==(other)
        return false unless other.is_a?(self.class)

        @signature == other.signature
      end

      # Get signature as hex string
      #
      # @return [String] Hex signature
      def to_hex
        @signature
      end

      # Get signature as bytes
      #
      # @return [String] Signature bytes
      def to_bytes
        [@signature].pack("H*")
      end

      # Get short signature (first 8 bytes of hex)
      #
      # @return [String] Short signature for quick comparison
      def short_signature
        @signature[0..15]
      end

      private

      # Extract metadata from validation result
      #
      # @return [Hash] Metadata hash
      def extract_metadata_from_result
        return {} unless @result

        {
          file_size: @result.file_size,
          chunk_count: @result.chunks.count,
          chunk_types: @result.chunks.map(&:type).sort,
          chunk_sizes: @result.chunks.map(&:length).sort,
          crcs: @result.chunks.filter_map do |c|
            c.crc_actual || c.crc_expected
          end,
        }
      end

      # Generate signature from metadata
      #
      # Uses SHA-256 on concatenated metadata for cryptographic strength.
      #
      # @return [String] Hex signature
      def generate_signature
        signature_data = signature_string
        Digest::SHA256.hexdigest(signature_data)
      end

      # Build signature string from metadata
      #
      # Creates a deterministic string representation of key file attributes.
      #
      # @return [String] Signature string
      def signature_string
        StringIO.new.tap do |io|
          # File size (8 bytes)
          io << [@metadata[:file_size]].pack("N")

          # Chunk count (4 bytes)
          io << [@metadata[:chunk_count]].pack("N")

          # Chunk types (sorted for consistency)
          @metadata[:chunk_types].each do |type|
            io << type.ljust(4, "\0")[0..3] # Fixed 4-char chunk types
          end

          # Chunk sizes (sorted for consistency)
          @metadata[:chunk_sizes].each do |size|
            io << [size].pack("N")
          end

          # CRC checksums (for integrity verification)
          @metadata[:crcs].each do |crc|
            io << [crc].pack("N")
          end
        end.string
      end

      # Extract quick metadata from file without full validation
      #
      # Reads just the PNG signature and chunk headers to create
      # a signature without loading entire file into memory.
      #
      # @param file_path [String] Path to PNG file
      # @return [Hash] Quick metadata hash
      def extract_quick_metadata(file_path)
        File.open(file_path, "rb") do |file|
          # Verify PNG signature first
          sig = file.read(8)
          expected_sig = [137, 80, 78, 71, 13, 10, 26, 10].pack("C*")
          unless sig == expected_sig
            raise ArgumentError, "Not a valid PNG file: #{file_path}"
          end

          # Quick scan to count chunks and collect metadata
          chunk_count = 0
          chunk_types = []
          chunk_sizes = []
          total_data_size = 0

          # Read entire file - no arbitrary limits for complete signatures
          while file.pos < File.size(file_path)
            # Read chunk length (4 bytes)
            length_bytes = file.read(4)
            break if length_bytes.nil? || length_bytes.length < 4

            chunk_length = length_bytes.unpack1("N")
            break if chunk_length > 10 * 1024 * 1024 # Sanity check

            # Read chunk type (4 bytes)
            type_bytes = file.read(4)
            break if type_bytes.nil? || type_bytes.length < 4

            chunk_type = type_bytes

            # Skip data
            file.seek(chunk_length, IO::SEEK_CUR)

            # Read CRC (4 bytes)
            crc_bytes = file.read(4)
            break if crc_bytes.nil? || crc_bytes.length < 4

            # Record metadata
            chunk_count += 1
            chunk_types << chunk_type
            chunk_sizes << chunk_length
            total_data_size += chunk_length

            # Stop if we found IEND
            break if chunk_type == "IEND"
          end

          {
            file_size: File.size(file_path),
            chunk_count: chunk_count,
            chunk_types: chunk_types.sort,
            chunk_sizes: chunk_sizes.sort,
            crcs: [], # Not easily available without validation
          }
        end
      rescue StandardError
        # Fallback to basic metadata
        {
          file_size: File.size(file_path),
          chunk_count: 0,
          chunk_types: [],
          chunk_sizes: [],
          crcs: [],
        }
      end
    end
  end
end
