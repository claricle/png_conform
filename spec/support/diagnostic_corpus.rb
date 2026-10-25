# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"
require "png_conform"

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
      Dir.glob("#{GOLDENS}/**/*", File::FNM_DOTMATCH, base: root).select do |path|
        File.file?(File.join(root, path))
      end.sort_by(&:b)
    end

    # Canonical pretty JSON for one input, named by its repo-relative path.
    # Uses the shared report contract with a repo-relative filename override.
    # @raise [RenderError] when validation itself raises
    def render(input)
      result = Services::ValidationService.validate_file(File.join(root, input))
        .validation_result
      report = result.to_lens_report(filename: input).to_h
      "#{JSON.pretty_generate(report)}\n"
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
      install(rendered)
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

    # Stage on the same filesystem, preserving the old tree if installation fails.
    def install(rendered)
      parent = File.join(root, FIXTURES)
      target = File.join(root, GOLDENS)
      stage = Dir.mktmpdir("diagnostic-goldens-", parent)
      installed = false
      begin
        replacement = File.join(stage, "replacement")
        backup = File.join(stage, "backup")
        FileUtils.mkdir_p(replacement)
        rendered.each do |path, text|
          staged = File.join(replacement, path.delete_prefix("#{GOLDENS}/"))
          FileUtils.mkdir_p(File.dirname(staged))
          File.binwrite(staged, text)
        end
        File.rename(target, backup) if File.exist?(target)
        begin
          File.rename(replacement, target)
          installed = true
        rescue SystemCallError
          begin
            File.rename(backup, target) if File.exist?(backup)
          rescue SystemCallError => e
            raise "cannot restore goldens; backup preserved at #{backup}: #{e.message}"
          end
          raise
        end
      ensure
        FileUtils.remove_entry(stage) if installed || !File.exist?(backup)
      end
    end

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
      fresh = render(input).b
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
