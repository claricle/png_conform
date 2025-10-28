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

      # File types
      FILE_TYPE_PNG = "PNG"
      FILE_TYPE_MNG = "MNG"
      FILE_TYPE_JNG = "JNG"
      FILE_TYPE_UNKNOWN = "UNKNOWN"

      # Add a chunk to the result
      def add_chunk(chunk)
        chunks << chunk
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

      # Find chunks by type
      def chunks_by_type(type)
        chunks.select { |chunk| chunk.type == type }
      end

      # Check if file has specific chunk type
      def has_chunk?(type)
        chunks.any? { |chunk| chunk.type == type }
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
    end
  end
end
