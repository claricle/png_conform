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
      attribute :requirement_id, :string
      attribute :chunk_index, :integer
      attribute :field, :string
      attribute :remediation, :string
      attribute :citation_uri, :string
      attribute :citation_label, :string
      attribute :profile, :string

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

      EXTRA_OPTIONS = %i[requirement_id chunk_index field remediation
                         citation_uri citation_label expected actual profile].freeze

      # Create error-level validation error
      def self.error(message, options = {})
        new(
          severity: SEVERITY_ERROR,
          message: message,
          chunk_type: options[:chunk_type],
          chunk_offset: options[:chunk_offset],
          error_type: options[:error_type],
          **options.slice(*EXTRA_OPTIONS),
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
          **options.slice(*EXTRA_OPTIONS),
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
          **options.slice(*EXTRA_OPTIONS),
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

      # Shared-contract location, or nil when no byte offset is known.
      def location
        return nil if chunk_offset.nil?

        Diagnostics::Location.new(
          byte_offset: chunk_offset, chunk_type: chunk_type,
          chunk_index: chunk_index, field: field
        )
      end

      # The immutable LensCore diagnostic; all structured fields derive here.
      def to_diagnostic
        LensCore::Diagnostic.new(
          severity: severity, kind: error_type || "validation",
          requirement_id: requirement_id || "png.#{error_type || 'unspecified'}",
          message: message, remediation: remediation,
          citations: lens_citations, context: lens_context,
          location: location&.to_lens
        )
      end

      # Plain-hash (JSON-safe) form of the shared diagnostic.
      def to_lens_h
        to_diagnostic.to_h
      end

      # Human rendering through the shared renderer.
      def to_human(profile_id: "png")
        LensCore::Renderers::Human.render(
          LensCore::Report.new(
            producer: LensCore::Producer.new(name: "png_conform",
                                             version: VERSION),
            profile: LensCore::Profile.new(id: profile_id),
            diagnostics: [to_diagnostic], valid: !error?
          ),
        )
      end

      LEGACY_KEYS = { message: :message, chunk_type: :chunk_type,
                      offset: :chunk_offset }.freeze

      # Hash-style reader kept as a compatibility alias for the context
      # entries that used to be plain hashes (:severity, :message,
      # :chunk_type, :offset).
      def [](key)
        return severity&.to_sym if key == :severity

        public_send(LEGACY_KEYS.fetch(key, key))
      end

      # Format for display (legacy, kept as a compatibility alias)
      def to_s
        parts = []
        parts << "[#{severity.upcase}]"
        parts << chunk_type if chunk_type
        parts << format("at 0x%05x", chunk_offset) if chunk_offset
        parts << message
        parts.join(" ")
      end

      private

      def lens_citations
        return [] if citation_uri.nil?

        [LensCore::Citation.new(uri: citation_uri, label: citation_label)]
      end

      # Profile policy findings have no byte position, so the profile and
      # chunk type travel as context instead of a location.
      def lens_context
        { "expected" => expected, "actual" => actual, "profile" => profile,
          "chunk_type" => (chunk_type if location.nil?) }.compact
      end
    end
  end
end
