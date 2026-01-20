# frozen_string_literal: true

module PngConform
  module Models
    # Domain model representing validation results for a file
    class ValidationResult < Lutaml::Model::Serializable
      attribute :filename, :string
      attribute :file_type, :string
      attribute :file_size, :integer
      attribute :valid, :boolean, default: -> { true }
      attribute :chunks, Chunk, collection: true, default: -> { [] }
      attribute :errors, ValidationError, collection: true, default: -> { [] }
      attribute :compression_ratio, :float
      attribute :crc_errors_count, :integer, default: -> { 0 }

      # Non-serialized hash map for fast chunk type lookup
      attr_reader :chunks_by_type_map

      # File types
      FILE_TYPE_PNG = "PNG"
      FILE_TYPE_MNG = "MNG"
      FILE_TYPE_JNG = "JNG"
      FILE_TYPE_UNKNOWN = "UNKNOWN"

      # Initialize with hash map for fast lookups
      def initialize(*args)
        super(*args)
        @chunks_by_type_map = {}
        rebuild_chunks_map
      end

      # Add a chunk to the result
      def add_chunk(chunk)
        chunks << chunk
        add_to_chunks_map(chunk)
      end

      # Add an error to the result
      def add_error(error)
        errors << error
        self.valid = false if error.error?
      end

      # Create error and add to result
      def error(message, options = {})
        add_error(ValidationError.error(message, options))
      end

      # Create warning and add to result
      def warning(message, options = {})
        add_error(ValidationError.warning(message, options))
      end

      # Create info and add to result
      def info(message, options = {})
        add_error(ValidationError.info(message, options))
      end

      # Check if validation passed
      def valid?
        valid
      end

      # Alias for filename (compatibility with reporters)
      def file_path
        filename
      end

      # Get only errors (not warnings or info)
      def error_messages
        errors.select(&:error?)
      end

      # Get only warnings
      def warning_messages
        errors.select(&:warning?)
      end

      # Get only info messages
      def info_messages
        errors.select(&:info?)
      end

      # Get error count
      def error_count
        error_messages.count
      end

      # Get warning count
      def warning_count
        warning_messages.count
      end

      # Get info count
      def info_count
        info_messages.count
      end

      # Get chunk count
      def chunk_count
        chunks.count
      end

      # Find chunks by type (O(1) hash lookup)
      def chunks_by_type(type)
        @chunks_by_type_map[type] || []
      end

      # Check if file has specific chunk type (O(1) hash lookup)
      def has_chunk?(type)
        @chunks_by_type_map.key?(type) && !@chunks_by_type_map[type].empty?
      end

      # Get IHDR chunk (PNG/JNG)
      def ihdr_chunk
        chunks_by_type("IHDR").first
      end

      # Get MHDR chunk (MNG)
      def mhdr_chunk
        chunks_by_type("MHDR").first
      end

      # Get JHDR chunk (JNG)
      def jhdr_chunk
        chunks_by_type("JHDR").first
      end

      # Summary for display
      def summary
        status = valid? ? "OK" : "ERRORS"
        "#{status}: #{filename} (#{file_type}, #{file_size} bytes, " \
          "#{chunk_count} chunks, #{error_count} errors, " \
          "#{warning_count} warnings)"
      end

      # Error summary for output (pngcheck format)
      def error_summary
        parts = []
        parts << "ERROR: #{filename}"
        errors.each do |error|
          parts << "  #{error.message}"
        end
        parts.join("\n")
      end

      private

      # Add chunk to hash map for fast lookup
      def add_to_chunks_map(chunk)
        chunk_type = chunk.type
        @chunks_by_type_map[chunk_type] ||= []
        @chunks_by_type_map[chunk_type] << chunk
      end

      # Rebuild hash map from chunks (for deserialization or external modification)
      def rebuild_chunks_map
        @chunks_by_type_map.clear
        chunks.each { |chunk| add_to_chunks_map(chunk) }
      end
    end
  end
end
