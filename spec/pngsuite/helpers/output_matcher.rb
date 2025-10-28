# frozen_string_literal: true

module PngSuite
  module Helpers
    # Helper for comparing png_conform output with pngcheck expectations
    class OutputMatcher
      attr_reader :fixture_path, :expected_output_path

      def initialize(fixture_path, expected_output_path)
        @fixture_path = fixture_path
        @expected_output_path = expected_output_path
      end

      def matches?
        normalize(actual_output) == normalize(expected_output)
      end

      def actual_output
        @actual_output ||= run_png_conform
      end

      def expected_output
        @expected_output ||= if File.exist?(@expected_output_path)
                               File.read(@expected_output_path).strip
                             else
                               ""
                             end
      end

      def failure_message
        <<~MSG
          Expected png_conform output to match pngcheck output for #{File.basename(@fixture_path)}

          Expected:
          #{expected_output}

          Actual:
          #{actual_output}

          Normalized Expected:
          #{normalize(expected_output)}

          Normalized Actual:
          #{normalize(actual_output)}
        MSG
      end

      private

      def run_png_conform
        # Run png_conform CLI command with 'check' subcommand
        exe_path = File.expand_path("../../../exe/png_conform", __dir__)
        output = `#{exe_path} check #{@fixture_path} 2>&1`
        output.strip
      end

      def normalize(output)
        # Normalize paths (remove absolute paths)
        # Normalize whitespace
        # Return comparable string
        output
          .gsub(%r{/[^:]+/pngsuite/}, "pngsuite/")
          .gsub(/\s+/, " ")
          .strip
      end
    end

    # RSpec matcher
    RSpec::Matchers.define :match_pngcheck_output do |expected_path|
      match do |fixture_path|
        @matcher = OutputMatcher.new(fixture_path, expected_path)
        @matcher.matches?
      end

      failure_message do
        @matcher.failure_message
      end
    end
  end
end
