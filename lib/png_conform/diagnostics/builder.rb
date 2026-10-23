# frozen_string_literal: true

module PngConform
  module Diagnostics
    # The single constructor for conformance diagnostics.
    #
    # Resolves a catalog requirement ID to its severity, kind and citation and
    # returns a Models::ValidationError carrying that identity. The message and
    # the dynamic data (location, expected/actual, field) stay separate from
    # the rule identity. An unknown ID raises Catalog::UnknownIdError.
    module Builder
      DETAIL_KEYS = %i[chunk_type offset chunk_index field expected actual
                       profile].freeze

      module_function

      # @param id [String] catalog requirement ID
      # @param message [String] rendered finding text
      # @param citation_note [String, nil] appended to the citation label
      #   (the profile name for profile policy findings)
      # @param catalog [Catalog]
      # @param detail [Hash] chunk_type:, offset: (absolute byte offset),
      #   chunk_index:, field:, expected:, actual:, profile:
      # @return [Models::ValidationError]
      def build(id, message, citation_note: nil, catalog: Catalog.default,
                **detail)
        unknown = detail.keys - DETAIL_KEYS
        raise ArgumentError, "unknown detail #{unknown.inspect}" if unknown.any?

        requirement = catalog.fetch(id)
        Models::ValidationError.new(
          severity: requirement.severity, message: message,
          error_type: requirement.kind, requirement_id: id,
          chunk_offset: detail[:offset],
          **detail.except(:offset).transform_values { |v| v&.to_s },
          **citation_attributes(requirement.citation, citation_note)
        )
      end

      def citation_attributes(citation, note)
        return {} if citation.nil?

        spec = citation.specification
        label = "#{spec.name} #{spec.version}, section #{citation.section}: " \
                "#{citation.title}"
        label += " (#{note})" if note
        { citation_uri: spec.url || "urn:png-conform:specification:#{spec.key}",
          citation_label: label }
      end
    end
  end
end
