# frozen_string_literal: true

require "fileutils"
require "json"
require "stringio"
require "png_conform"
require "png_conform/reporters/json_reporter"

module PngConform
  # Mirrors every checked-in fixture as a canonical JSON golden and compares
  # the two without side effects. Used by script/regenerate_diagnostic_goldens
  # and spec/structured_diagnostics/corpus_spec.rb so both agree on what the
  # corpus is, how a golden is named and what counts as drift.
  class DiagnosticCorpus
    # Fixture directories (relative to spec/fixtures) and the input
    # extensions mirrored from each. The golden tree repeats the same
    # directory names under spec/fixtures/diagnostics/.
    SOURCES = {
      "pngsuite" => %w[.png],
      "idot" => %w[.png],
      "mng" => %w[.mng],
      "jng" => %w[.jng],
    }.freeze

    FIXTURES = "spec/fixtures"
    GOLDENS = "#{FIXTURES}/diagnostics".freeze
    GOLDEN_SUFFIX = ".json"

    # One drift finding: kind is one of missing, extra, stale, reordered,
    # schema, host, render.
    Problem = Struct.new(:kind, :path, :detail) do
      def to_s
        [kind.to_s.upcase, path, detail].compact.join(" ")
      end
    end

    # A validator crash is an unreviewable hole in the corpus, never a golden.
    class RenderError < StandardError; end

    attr_reader :root

    def initialize(root)
      @root = File.expand_path(root)
    end

    # Repo-relative input paths in bytewise sorted order.
    def inputs
      SOURCES.flat_map do |dir, extensions|
        Dir.glob("#{FIXTURES}/#{dir}/**/*", base: root).select do |path|
          File.file?(File.join(root, path)) &&
            extensions.include?(File.extname(path).downcase)
        end
      end.sort_by(&:b)
    end

    # spec/fixtures/pngsuite/x/y.png -> spec/fixtures/diagnostics/pngsuite/x/y.png.json
    def golden_path(input)
      relative = input.delete_prefix("#{FIXTURES}/")
      "#{GOLDENS}/#{relative}#{GOLDEN_SUFFIX}"
    end

    # Repo-relative golden paths actually present, bytewise sorted.
    def goldens
      Dir.glob("#{GOLDENS}/**/*", base: root).select do |path|
        File.file?(File.join(root, path))
      end.sort_by(&:b)
    end

    # Canonical pretty JSON for one input, named by its repo-relative path.
    # Runs from the repo root so the recorded filename never depends on the
    # caller's directory.
    # @raise [RenderError] when validation itself raises
    def render(input)
      analysis = Dir.chdir(root) do
        Services::ValidationService.validate_file(input)
      end
      out = StringIO.new
      Reporters::JsonReporter.new(out, colorize: false).report(analysis)
      out.string
    rescue StandardError => e
      raise RenderError, "#{input}: #{e.class}: #{e.message}"
    end

    # Non-mutating comparison of the golden tree against fresh output.
    # @return [Array<Problem>] empty when the tree is current
    def check
      expected = inputs.to_h { |input| [golden_path(input), input] }
      problems = missing_and_stale(expected)
      (goldens - expected.keys).each do |path|
        problems << Problem.new(:extra, path, "no matching fixture input")
      end
      problems
    end

    # Regenerates every golden, all-or-nothing.
    # @raise [RuntimeError] when the target set is dirty or partial
    def write
      orphans = goldens - inputs.map { |input| golden_path(input) }
      unless orphans.empty?
        raise "dirty golden tree, unexpected files: #{orphans.join(', ')}"
      end

      rendered = inputs.to_h { |input| [golden_path(input), render(input)] }
      rendered.each do |path, text|
        target = File.join(root, path)
        FileUtils.mkdir_p(File.dirname(target))
        File.binwrite(target, text)
      end
      rendered.keys
    end

    # Problems in one golden's text independent of fresh output.
    def self.document_problems(path, text, root: nil)
      document = JSON.parse(text)
      problems = schema_problems(path, document)
      if host_dependent?(text, root)
        problems << Problem.new(:host, path,
                                "contains an absolute or host-specific path")
      end
      problems
    rescue JSON::ParserError => e
      [Problem.new(:schema, path, "not parseable JSON: #{e.message[0, 60]}")]
    end

    def self.schema_problems(path, document)
      unless document.is_a?(Hash)
        return [Problem.new(:schema, path, "top level is not an object")]
      end

      version = document["schema_version"]
      if version.nil?
        [Problem.new(:schema, path, "schema_version missing")]
      elsif version != LensCore::SCHEMA_VERSION
        [Problem.new(:schema, path,
                     "schema_version #{version.inspect}, " \
                     "expected #{LensCore::SCHEMA_VERSION}")]
      else
        []
      end
    end

    def self.host_dependent?(text, root)
      return true if root && text.include?(root)

      text.match?(%r{"(?:/(?:Users|home|tmp|var|private)/|[A-Za-z]:\\)})
    end

    private

    def missing_and_stale(expected)
      expected.flat_map do |path, input|
        full = File.join(root, path)
        next [Problem.new(:missing, path, "no golden for #{input}")] unless
          File.file?(full)

        compare(path, input, File.binread(full))
      rescue RenderError => e
        [Problem.new(:render, path, e.message)]
      end
    end

    def compare(path, input, actual)
      fresh = render(input)
      problems = self.class.document_problems(path, actual, root: root)
      return problems if actual == fresh

      kind = same_content?(actual, fresh) ? :reordered : :stale
      detail = kind == :reordered ? "same data, different key order or layout" : "differs from fresh output"
      problems << Problem.new(kind, path, detail)
    end

    def same_content?(actual, fresh)
      JSON.parse(actual) == JSON.parse(fresh)
    rescue JSON::ParserError
      false
    end
  end
end
