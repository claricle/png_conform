# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "png_conform/reporters/summary_reporter"
require "png_conform/models/file_analysis"
require "png_conform/models/image_info"
require "png_conform/models/compression_info"
require "png_conform/models/validation_result"

RSpec.describe PngConform::Reporters::SummaryReporter do
  let(:output) { StringIO.new }
  let(:reporter) { described_class.new(output) }

  describe "#report" do
    context "with valid PNG file" do
      let(:image_info) do
        PngConform::Models::ImageInfo.new(
          width: 32,
          height: 32,
          bit_depth: 1,
          color_type: "grayscale",
          interlaced: false,
          animated: false,
        )
      end

      let(:compression_info) do
        PngConform::Models::CompressionInfo.new(
          compression_ratio: -28.1,
        )
      end

      let(:validation_result) do
        PngConform::Models::ValidationResult.new(
          valid: true,
        )
      end

      let(:file_analysis) do
        PngConform::Models::FileAnalysis.new(
          file_path: "test.png",
          file_size: 164,
          image_info: image_info,
          compression_info: compression_info,
          validation_result: validation_result,
        )
      end

      it "outputs pngcheck-compatible summary line" do
        reporter.report(file_analysis)
        expect(output.string).to match(/test\.png/)
      end
    end

    context "with invalid PNG file" do
      let(:validation_result) do
        result = PngConform::Models::ValidationResult.new(valid: false)
        result.error("Invalid signature")
        result
      end

      let(:file_analysis) do
        PngConform::Models::FileAnalysis.new(
          file_path: "invalid.png",
          file_size: 100,
          validation_result: validation_result,
        )
      end

      it "outputs ERROR status" do
        reporter.report(file_analysis)

        expect(output.string).to match(/ERROR.*invalid\.png/)
      end
    end
  end
end
