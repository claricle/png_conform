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
      attribute :image_info, ImageInfo
      attribute :compression_info, CompressionInfo

      # Analyzer results (proper Model → Formatter pattern)
      attribute :resolution_analysis, :hash
      attribute :optimization_analysis, :hash
      attribute :metrics, :hash

      # Total chunk count
      def chunk_count
        chunks.size
      end

      # Get chunks (either from direct attribute or validation_result)
      def chunks
        validation_result&.chunks || []
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

      # Delegate to validation_result for API compatibility
      def errors
        validation_result&.errors || []
      end

      def error_messages
        validation_result&.error_messages || []
      end

      def error_count
        validation_result&.error_count || 0
      end

      def warning_count
        validation_result&.warning_count || 0
      end

      def info_count
        validation_result&.info_count || 0
      end

      # Delegate to compression_info
      def compression_ratio
        compression_info&.compression_ratio
      end

      # Convert to complete hash for serialization
      # This provides a single source of truth for all output formats
      def to_h
        hash = {
          "filename" => file_path,
          "file_type" => file_type,
          "file_size" => file_size,
          "compression_ratio" => compression_ratio,
          "crc_errors_count" => validation_result&.crc_errors_count || 0,
          "valid" => valid?,
        }

        # Add image info if available
        hash["image"] = image_info.to_h if image_info

        # Add chunks info
        if chunks.any?
          hash["chunks"] = {
            "total" => chunk_count,
            "types" => chunks.map(&:type).uniq.sort,
          }
        end

        # Add errors if any
        if validation_result&.errors&.any?
          hash["errors"] = validation_result.errors.map do |error|
            error_hash = {
              "severity" => error.severity,
              "message" => error.message,
            }
            error_hash["chunk_type"] = error.chunk_type if error.chunk_type
            error_hash["expected"] = error.expected if error.expected
            error_hash["actual"] = error.actual if error.actual
            error_hash
          end
        end

        # Add resolution analysis if available
        hash["resolution"] = resolution_analysis if resolution_analysis && !resolution_analysis.empty?

        # Add optimization if available
        if optimization_analysis && optimization_analysis[:suggestions]&.any?
          hash["optimization"] = {
            "suggestions" => optimization_analysis[:suggestions],
            "total_savings_bytes" => optimization_analysis[:potential_savings_bytes],
            "total_savings_percent" => optimization_analysis[:potential_savings_percent],
          }
        end

        # Add recommendations
        recs = extract_recommendations
        hash["recommendations"] = recs if recs&.any?

        hash
      end

      # Extract recommendations from analyzers
      def extract_recommendations
        recs = []

        # From resolution analysis
        if resolution_analysis && resolution_analysis[:recommendations]
          recs.concat(resolution_analysis[:recommendations].map { |r| r[:message] })
        end

        recs.empty? ? nil : recs
      end
    end
  end
end
