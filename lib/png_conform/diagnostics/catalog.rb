# frozen_string_literal: true

require "yaml"

module PngConform
  module Diagnostics
    # Registry of every stable diagnostic requirement ID.
    #
    # Loads and validates config/diagnostics.yml and returns typed, frozen
    # data for diagnostic construction. Validation rejects duplicate IDs,
    # unknown formats/kinds/severities/specifications, missing citations on
    # conformance requirements, and citations on informational findings.
    class Catalog
      class Error < StandardError; end
      class DuplicateIdError < Error; end
      class UnknownIdError < Error; end
      class InvalidEntryError < Error; end

      DEFAULT_PATH = File.expand_path("../../../config/diagnostics.yml",
                                      __dir__)

      FORMATS = %w[png apng mng jng all].freeze
      SEVERITIES = %w[error warning info].freeze
      KINDS = %w[
        length ordering multiplicity presence value encoding consistency
        integrity policy information
      ].freeze
      SCHEMA_VERSION = 1
      EXCLUSION_FIELDS = %w[paths classification decision rationale
                            evidence].freeze
      SPECIFICATION_FIELDS = %w[name version].freeze

      Specification = Struct.new(:key, :name, :version, :url,
                                 keyword_init: true)

      Citation = Struct.new(:specification, :section, :title,
                            keyword_init: true) do
        def to_h
          { specification: specification.name,
            version: specification.version,
            section: section,
            title: title }
        end
      end

      Emitter = Struct.new(:file, :call, :sites, keyword_init: true)

      # A source that was inventoried and deliberately left out of the
      # catalog, with the evidence for that decision.
      Exclusion = Struct.new(:key, :paths, :classification, :decision,
                             :rationale, :evidence, :constants,
                             :reference_pattern, :private_helpers,
                             :uncalled_helpers, keyword_init: true)

      Requirement = Struct.new(:id, :format, :kind, :severity, :citation,
                               :abstract, :emitters, keyword_init: true) do
        def informational?
          kind == "information"
        end

        def abstract?
          abstract
        end
      end

      class << self
        # @return [Catalog] the catalog shipped with the gem
        def default
          @default ||= load
        end

        # @param path [String] path to a catalog YAML file
        # @return [Catalog]
        def load(path = DEFAULT_PATH)
          new(parse(path), path)
        end

        private

        def parse(path)
          ensure_unique_keys!(Psych.parse_file(path))
          YAML.safe_load_file(path)
        end

        # Psych keeps the last of two equal keys; walk the AST so a
        # duplicated requirement ID fails loudly instead.
        def ensure_unique_keys!(node)
          return unless node.respond_to?(:children) && node.children

          if node.is_a?(Psych::Nodes::Mapping)
            keys = node.children.each_slice(2).map { |k, _| k.value }
            dup = keys.group_by(&:itself).find { |_, v| v.size > 1 }&.first
            raise DuplicateIdError, "duplicate key #{dup.inspect}" if dup
          end
          node.children.each { |c| ensure_unique_keys!(c) }
        end
      end

      attr_reader :specifications, :exclusions, :path

      # @param data [Hash] parsed catalog document
      # @param path [String, nil] source path, for error messages
      def initialize(data, path = nil)
        @path = path
        @specifications = build_specifications(data)
        @entries = {}
        add_section(data, "requirements", informational: false)
        add_section(data, "informational", informational: true)
        @entries.freeze
        @exclusions = build_exclusions(data)
        freeze
      end

      # @return [Requirement]
      # @raise [UnknownIdError]
      def fetch(id)
        @entries.fetch(id) { raise UnknownIdError, "unknown requirement ID #{id.inspect}" }
      end

      def key?(id)
        @entries.key?(id)
      end

      def ids
        @entries.keys
      end

      def each(&block)
        @entries.each_value(&block)
      end
      include Enumerable

      def requirements
        reject(&:informational?)
      end

      def informational
        select(&:informational?)
      end

      private

      def build_exclusions(data)
        (data["excluded_sources"] || {}).to_h do |key, raw|
          EXCLUSION_FIELDS.each do |field|
            raise InvalidEntryError, "excluded source #{key}: missing #{field}" if raw[field].nil? || raw[field].empty?
          end
          [key, Exclusion.new(
            key: key, paths: raw["paths"], classification: raw["classification"],
            decision: raw["decision"], rationale: raw["rationale"],
            evidence: raw["evidence"], constants: raw["constants"] || [],
            reference_pattern: raw["reference_pattern"],
            private_helpers: raw["private_helpers"] || [],
            uncalled_helpers: raw["uncalled_helpers"] || []
          ).freeze]
        end.freeze
      end

      def build_specifications(data)
        unless data["schema_version"] == SCHEMA_VERSION
          raise InvalidEntryError,
                "unsupported schema_version #{data['schema_version'].inspect}"
        end

        (data["specifications"] || {}).to_h do |key, spec|
          SPECIFICATION_FIELDS.each do |field|
            raise InvalidEntryError, "specification #{key}: missing #{field}" if spec[field].to_s.empty?
          end
          [key, Specification.new(key: key, name: spec["name"],
                                  version: spec["version"].to_s,
                                  url: spec["url"]).freeze]
        end.freeze
      end

      def add_section(data, section, informational:)
        (data[section] || {}).each do |id, raw|
          raise DuplicateIdError, "duplicate requirement ID #{id}" if @entries.key?(id)

          @entries[id] = build(id, raw, informational)
        end
      end

      def build(id, raw, informational)
        fail_entry = ->(msg) { raise InvalidEntryError, "#{id}: #{msg}" }
        fail_entry.call("not a mapping") unless raw.is_a?(Hash)
        check_member(raw, "format", FORMATS, fail_entry)
        check_member(raw, "kind", KINDS, fail_entry)
        check_member(raw, "severity", SEVERITIES, fail_entry)
        check_section_kind(raw, informational, fail_entry)

        Requirement.new(
          id: id, format: raw["format"], kind: raw["kind"],
          severity: raw["severity"],
          citation: build_citation(raw, informational, fail_entry),
          abstract: raw["abstract"] == true,
          emitters: build_emitters(raw["emitters"], fail_entry)
        ).freeze
      end

      def check_member(raw, field, allowed, fail_entry)
        return if allowed.include?(raw[field])

        fail_entry.call("unknown #{field} #{raw[field].inspect}")
      end

      def check_section_kind(raw, informational, fail_entry)
        return if (raw["kind"] == "information") == informational

        fail_entry.call("kind #{raw['kind']} is in the wrong catalog section")
      end

      def build_citation(entry, informational, fail_entry)
        raw = entry["citation"]
        if informational
          fail_entry.call("informational findings carry no citation") if raw
          return nil
        end
        # Abstract shared-helper findings have no requirement of their own.
        return nil if raw.nil? && entry["abstract"] == true

        fail_entry.call("missing citation") unless raw.is_a?(Hash)
        spec = @specifications[raw["specification"]]
        fail_entry.call("unknown specification #{raw['specification'].inspect}") unless spec
        %w[section title].each do |field|
          fail_entry.call("citation missing #{field}") if raw[field].to_s.empty?
        end
        Citation.new(specification: spec, section: raw["section"].to_s,
                     title: raw["title"]).freeze
      end

      def build_emitters(raw, fail_entry)
        fail_entry.call("missing emitters") if !raw.is_a?(Array) || raw.empty?

        raw.map do |e|
          fail_entry.call("emitter needs file and call") if e["file"].to_s.empty? || e["call"].to_s.empty?
          Emitter.new(file: e["file"], call: e["call"],
                      sites: e["sites"] || 1).freeze
        end.freeze
      end
    end
  end
end
