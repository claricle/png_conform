# frozen_string_literal: true

module PngConform
  module Services
    # File strategy service for reader selection
    #
    # Determines the optimal reader type based on file characteristics
    # and validation options. This enables automatic reader selection for
    # better performance and memory efficiency.
    #
    class FileStrategy
      # Large file threshold (10MB) - files larger than this use streaming
      LARGE_FILE_THRESHOLD = 10 * 1024 * 1024

      class << self
        # Determine the appropriate reader type for a file
        #
        # @param file_path [String] Path to the PNG file
        # @param options [Hash] Validation options
        # @return [Symbol] Reader type (:streaming or :full_load)
        def reader_type_for(file_path, options = {})
          file_size = File.size(file_path)

          # Use streaming for large files unless explicitly forced
          if file_size > LARGE_FILE_THRESHOLD && !options[:force_full]
            :streaming
          else
            :full_load
          end
        end

        # Check if a file is considered large
        #
        # @param file_path [String] Path to the PNG file
        # @return [Boolean] True if file is large
        def large_file?(file_path)
          File.size(file_path) > LARGE_FILE_THRESHOLD
        end

        # Get the threshold for large file detection
        #
        # @return [Integer] Threshold in bytes
        def large_file_threshold
          LARGE_FILE_THRESHOLD
        end

        # Calculate recommended chunk size for processing
        #
        # For large files, smaller chunks are better for memory management
        #
        # @param file_path [String] Path to the PNG file
        # @return [Integer] Recommended chunk size in bytes
        def recommended_chunk_size(file_path)
          file_size = File.size(file_path)

          if file_size > 100 * 1024 * 1024 # > 100MB
            8192 # 8KB chunks for very large files
          elsif file_size > 10 * 1024 * 1024 # > 10MB
            16384 # 16KB chunks for large files
          else
            65536 # 64KB chunks for normal files
          end
        end

        # Estimate memory usage for full-load reader
        #
        # @param file_path [String] Path to the PNG file
        # @return [Integer] Estimated memory in bytes
        def estimate_memory_usage(file_path)
          file_size = File.size(file_path)
          # Estimate: file_size + overhead for chunks (rough estimate)
          # Each chunk adds overhead for BinData structures
          file_size * 1.2
        end
      end
    end
  end
end
