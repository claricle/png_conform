# frozen_string_literal: true

require "lutaml/model"

module PngConform
  module Models
    # Top-level domain model for PNG file analysis
    class FileAnalysis < Lutaml::Model::Serializable
      attribute :file_path, :string
      attribute :file_size, :integer
      attribute :file_type, :string # 'PNG', 'MNG', 'JNG'
      attribute :validation_result, ValidationResult
      attribute :chunks, ChunkInfo, collection: true
      attribute :image_info, ImageInfo
      attribute :compression_info, CompressionInfo

      # Total chunk count
      def chunk_count
        chunks&.size || 0
      end

      # Check if file is valid
      def valid?
        validation_result&.valid? || false
      end

      # Get validation status text
      def status
        valid? ? "OK" : "ERROR"
      end

      # Format file header line (for verbose mode)
      # Example: "File: file.png (164 bytes)"
      def file_header
        "File: #{file_path} (#{file_size} bytes)"
      end

      # Format summary line (default output mode)
      # Example: "OK: file.png (32x32, 1-bit grayscale, non-interlaced, -28.1%)."
      def summary_line
        parts = []
        parts << "#{status}:"
        parts << file_path
        if image_info
          info_parts = []
          info_parts << image_info.summary
          info_parts << compression_info.summary if compression_info
          parts << "(#{info_parts.join(', ')})"
        end
        "#{parts.join(' ')}."
      end

      # Format validation summary (for verbose mode)
      # Example: "No errors detected in file.png (4 chunks, -28.1% compression)."
      def validation_summary
        return validation_result.error_summary if validation_result && !valid?

        parts = []
        parts << "No errors detected in #{file_path}"
        detail_parts = []
        detail_parts << "#{chunk_count} chunks" if chunk_count.positive?
        if compression_info
          detail_parts << "#{compression_info.summary} compression"
        end
        parts << "(#{detail_parts.join(', ')})" unless detail_parts.empty?
        "#{parts.join(' ')}."
      end

      # Alias for compatibility with reporters
      alias filename file_path

      # Delegate to validation_result
      def errors
        validation_result&.errors || []
      end

      # Delegate to compression_info
      def compression_ratio
        compression_info&.compression_ratio
      end
    end
  end
end
