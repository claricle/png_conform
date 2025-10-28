# frozen_string_literal: true

module PngConform
  module Models
    # Domain model representing a validation error or warning
    class ValidationError < Lutaml::Model::Serializable
      attribute :severity, :string
      attribute :message, :string
      attribute :chunk_type, :string
      attribute :chunk_offset, :integer
      attribute :error_type, :string
      attribute :expected, :string
      attribute :actual, :string

      # Severity levels
      SEVERITY_ERROR = "error"
      SEVERITY_WARNING = "warning"
      SEVERITY_INFO = "info"

      # Error types
      ERROR_TYPE_SIGNATURE = "signature"
      ERROR_TYPE_CRC = "crc"
      ERROR_TYPE_CHUNK_ORDER = "chunk_order"
      ERROR_TYPE_CHUNK_DATA = "chunk_data"
      ERROR_TYPE_ZLIB = "zlib"
      ERROR_TYPE_MISSING_CHUNK = "missing_chunk"
      ERROR_TYPE_INVALID_VALUE = "invalid_value"
      ERROR_TYPE_PROFILE = "profile"

      # Create error-level validation error
      def self.error(message, options = {})
        new(
          severity: SEVERITY_ERROR,
          message: message,
          chunk_type: options[:chunk_type],
          chunk_offset: options[:chunk_offset],
          error_type: options[:error_type],
        )
      end

      # Create warning-level validation error
      def self.warning(message, options = {})
        new(
          severity: SEVERITY_WARNING,
          message: message,
          chunk_type: options[:chunk_type],
          chunk_offset: options[:chunk_offset],
          error_type: options[:error_type],
        )
      end

      # Create info-level validation error
      def self.info(message, options = {})
        new(
          severity: SEVERITY_INFO,
          message: message,
          chunk_type: options[:chunk_type],
          chunk_offset: options[:chunk_offset],
          error_type: options[:error_type],
        )
      end

      # Check if this is an error
      def error?
        severity == SEVERITY_ERROR
      end

      # Check if this is a warning
      def warning?
        severity == SEVERITY_WARNING
      end

      # Check if this is info
      def info?
        severity == SEVERITY_INFO
      end

      # Format for display
      def to_s
        parts = []
        parts << "[#{severity.upcase}]"
        parts << chunk_type if chunk_type
        parts << format("at 0x%05x", chunk_offset) if chunk_offset
        parts << message
        parts.join(" ")
      end
    end
  end
end
