# frozen_string_literal: true

require_relative "pngcheck_parser"

module PngSuite
  module Helpers
    # Validates PNG files using png_conform Ruby API and compares against pngcheck
    class SemanticValidator
      attr_reader :fixture_path, :expected_output_path

      def initialize(fixture_path, expected_output_path)
        @fixture_path = fixture_path
        @expected_output_path = expected_output_path
      end

      def matches?
        expected_info.fetch(:valid) == actual_valid? &&
          (!expected_info.fetch(:valid) || dimensions_match?) &&
          (!expected_info.fetch(:valid) || bit_depth_matches?) &&
          (!expected_info.fetch(:valid) || color_type_matches?) &&
          (!expected_info.fetch(:valid) || interlaced_matches?)
      end

      def failure_message
        [
          "Expected png_conform validation to match pngcheck for #{File.basename(@fixture_path)}",
          "",
          "Expected (from pngcheck):",
          format_expected,
          "",
          "Actual (from png_conform Ruby API):",
          format_actual,
          "",
          "Mismatches:",
          mismatches.join("\n"),
        ].join("\n")
      end

      private

      def expected_info
        @expected_info ||= PngcheckParser.new(expected_output).to_h
      end

      def expected_output
        @expected_output ||= File.read(@expected_output_path)
      end

      def actual_valid?
        validation_result&.valid? || false
      end

      def validation_service
        @validation_service ||= begin
          PngConform::Readers::StreamingReader.open(@fixture_path) do |reader|
            service = PngConform::Services::ValidationService.new(reader)
            # service.validate returns FileAnalysis
            @validation_result = service.validate
            service
          end
        rescue StandardError => e
          @validation_error = e
          nil
        end
      end

      # Returns FileAnalysis which delegates to ValidationResult
      def validation_result
        validation_service
        @validation_result
      end

      def ihdr_data_available?
        validation_service&.context&.retrieve(:width)
      end

      def dimensions_match?
        return false unless ihdr_data_available?

        ctx = validation_service.context
        width = ctx.retrieve(:width)
        height = ctx.retrieve(:height)
        expected_dims = expected_info.fetch(:dimensions, {})
        width == expected_dims[:width] && height == expected_dims[:height]
      end

      def bit_depth_matches?
        return false unless ihdr_data_available?

        actual = calculate_total_bit_depth
        expected = expected_info.fetch(:bit_depth)
        actual == expected
      end

      def calculate_total_bit_depth
        ctx = validation_service.context
        bit_depth = ctx.retrieve(:bit_depth)
        color_type = ctx.retrieve(:color_type)

        case color_type
        when 0 # Grayscale
          bit_depth
        when 2 # RGB (truecolor)
          bit_depth * 3
        when 3 # Palette (indexed-color)
          bit_depth
        when 4 # Grayscale + alpha
          bit_depth * 2
        when 6 # RGB + alpha (truecolor with alpha)
          bit_depth * 4
        else
          bit_depth
        end
      end

      def color_type_matches?
        return false unless ihdr_data_available?

        actual = validation_service.context.retrieve(:color_type_name)
        expected = expected_info.fetch(:color_type)
        normalize_color_type(actual) == normalize_color_type(expected)
      end

      def interlaced_matches?
        return false unless ihdr_data_available?

        actual = validation_service.context.retrieve(:interlace) == 1
        expected = expected_info.fetch(:interlaced, false)
        actual == expected
      end

      def normalize_color_type(type)
        normalized = type.to_s.downcase.gsub(/[-_\s]+/, "")

        # Map equivalent terms
        case normalized
        when "truecolor" then "rgb"
        when "indexedcolor", "palette" then "palette"
        when "truecolorwithalpha", "rgbwithalpha" then "rgb+alpha"
        when "grayscalewithalpha" then "grayscale+alpha"
        else normalized
        end
      end

      def format_expected
        info = expected_info
        if info[:valid]
          dims = info[:dimensions]
          "Valid: #{dims[:width]}x#{dims[:height]}, " \
            "#{info[:bit_depth]}-bit #{info[:color_type]}, " \
            "#{info[:interlaced] ? 'interlaced' : 'non-interlaced'}"
        else
          "Invalid: #{info[:reason] || 'Parse failed'}"
        end
      end

      def format_actual
        if actual_valid? && ihdr_data_available?
          ctx = validation_service.context
          width = ctx.retrieve(:width)
          height = ctx.retrieve(:height)
          total_bit_depth = calculate_total_bit_depth
          color_type = ctx.retrieve(:color_type_name)
          interlaced = ctx.retrieve(:interlace) == 1
          "Valid: #{width}x#{height}, " \
            "#{total_bit_depth}-bit #{color_type}, " \
            "#{interlaced ? 'interlaced' : 'non-interlaced'}"
        else
          reason = if @validation_error
                     "Parse failed: #{@validation_error.class}: #{@validation_error.message}"
                   else
                     validation_result&.error_messages&.first || "Parse failed"
                   end
          "Invalid: #{reason}"
        end
      end

      def mismatches
        issues = []

        if expected_info.fetch(:valid) != actual_valid?
          issues << "Validity: expected #{expected_info.fetch(:valid)}, " \
                    "got #{actual_valid?}"
        end

        if expected_info.fetch(:valid) && actual_valid?
          unless dimensions_match?
            exp_dims = expected_info.fetch(:dimensions, {})
            if ihdr_data_available?
              ctx = validation_service.context
              act_dims = { width: ctx.retrieve(:width),
                           height: ctx.retrieve(:height) }
            else
              act_dims = {}
            end
            issues << "Dimensions: expected #{exp_dims[:width]}x#{exp_dims[:height]}, " \
                      "got #{act_dims[:width]}x#{act_dims[:height]}"
          end

          unless bit_depth_matches?
            actual_depth = ihdr_data_available? ? calculate_total_bit_depth : nil
            issues << "Bit depth: expected #{expected_info.fetch(:bit_depth)}, " \
                      "got #{actual_depth}"
          end

          unless color_type_matches?
            actual_type = ihdr_data_available? ? validation_service.context.retrieve(:color_type_name) : nil
            issues << "Color type: expected #{expected_info.fetch(:color_type)}, " \
                      "got #{actual_type}"
          end

          unless interlaced_matches?
            actual_interlaced = ihdr_data_available? ? (validation_service.context.retrieve(:interlace) == 1) : nil
            issues << "Interlaced: expected #{expected_info.fetch(:interlaced,
                                                                  false)}, " \
                      "got #{actual_interlaced}"
          end
        end

        issues
      end
    end

    # RSpec matcher for semantic validation
    RSpec::Matchers.define :pass_semantic_validation do |expected_output_path|
      match do |fixture_path|
        @validator = SemanticValidator.new(fixture_path, expected_output_path)
        @validator.matches?
      end

      failure_message do
        @validator.failure_message
      end
    end
  end
end
