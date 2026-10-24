# frozen_string_literal: true

require "json"
require "fileutils"
require "pathname"
require_relative "../../png_conform"

module PngConform
  module Diagnostics
    # Canonical corpus reports. Checking compares bytes, including diagnostic
    # order, and never creates directories or repairs files.
    class GoldenGenerator
      EXTENSIONS = %w[.png .mng .jng].freeze

      def initialize(root:, fixtures: "spec/fixtures",
                     goldens: "spec/fixtures/diagnostics", output: $stdout)
        @root = Pathname.new(root).expand_path
        @fixtures = @root.join(fixtures)
        @goldens = @root.join(goldens)
        @output = output
      end

      # Returns a process exit status; require exactly one explicit mode.
      def run(arguments)
        unless [["--write"], ["--check"]].include?(arguments)
          @output.puts "Usage: regenerate_diagnostic_goldens --write|--check"
          return 2
        end

        expected = reports
        extra = golden_files - expected.keys
        extra.each { |path| @output.puts "extra: #{relative(path)}" }
        if arguments == ["--write"]
          return 1 unless extra.empty?

          expected.each do |path, bytes|
            FileUtils.mkdir_p(path.dirname)
            File.binwrite(path, bytes)
          end
          @output.puts "wrote #{expected.size} goldens"
          return 0
        end

        check(expected, extra)
      end

      private

      def relative(path)
        path.relative_path_from(@root).to_s
      end

      def fixture_files
        @fixtures.glob("**/*").select do |path|
          path.file? && EXTENSIONS.include?(path.extname.downcase) &&
            !path.to_s.start_with?("#{@goldens}/")
        end.sort_by { |path| relative(path).b }
      end

      def golden_files
        @goldens.glob("**/*").select(&:file?)
          .sort_by { |path| relative(path).b }
      end

      def reports
        fixture_files.to_h do |path|
          result = Services::ValidationService.validate_file(path.to_s)
            .validation_result
          report = result.to_lens_report(filename: relative(path)).to_h
          target = @goldens.join("#{path.relative_path_from(@fixtures)}.json")
          [target, "#{JSON.pretty_generate(report)}\n"]
        end
      end

      def check(expected, extra)
        failures = expected.count do |path, bytes|
          problem = if !path.file?
                      "missing"
                    elsif File.binread(path) != bytes.b
                      "stale (content or ordering differs)"
                    end
          @output.puts "#{problem}: #{relative(path)}" if problem
          problem
        end
        return 1 unless failures.zero? && extra.empty?

        @output.puts "#{expected.size} goldens match"
        0
      end
    end
  end
end
