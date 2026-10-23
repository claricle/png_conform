# frozen_string_literal: true

require "spec_helper"
require "png_conform/reporters/verbose_reporter"

RSpec.describe PngConform::Reporters::VerboseReporter do
  let(:reporter) { described_class.new }
  let(:result) { create_file_analysis }

  describe "#report" do
    it "outputs formatted report" do
      expect { reporter.report(result) }.not_to raise_error
    end

    it "includes file information" do
      output = capture_output { reporter.report(result) }
      expect(output).to include("test.png")
    end
  end

  private

  def create_file_analysis
    PngConform::Models::FileAnalysis.new(
      file_path: "test.png",
      file_size: 1024,
      validation_result: create_validation_result,
      image_info: create_image_info,
      chunks: [],
    )
  end

  def create_validation_result
    PngConform::Models::ValidationResult.new(
      valid: true,
      errors: [],
      warnings: [],
    )
  end

  def create_file_analysis
    PngConform::Models::FileAnalysis.new(
      file_path: "test.png",
      file_size: 1024,
      validation_result: create_validation_result,
      image_info: create_image_info,
      chunks: [],
    )
  end

  def create_validation_result
    PngConform::Models::ValidationResult.new(
      valid: true,
      errors: [],
      warnings: [],
    )
  end

  def create_image_info
    PngConform::Models::ImageInfo.new(
      width: 800,
      height: 600,
      bit_depth: 8,
      color_type: 2,
      compression_method: 0,
      filter_method: 0,
      interlace_method: 0,
    )
  end

  def capture_output
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  describe "diagnostic rendering" do
    it "prints location and citation lines from the shared renderer" do
      error = PngConform::Diagnostics::Builder.build(
        "all.signature.unknown", "Invalid PNG signature",
        chunk_type: "SIGNATURE", offset: 0
      )
      analysis = result
      analysis.validation_result.add_error(error)
      output = capture_output { reporter.report(analysis) }

      expect(output).to include("Invalid PNG signature")
      expect(output).to include("  at byte offset 0")
      expect(output).to include("see: ISO/IEC 15948")
      expect(output.scan("Invalid PNG signature").size).to eq(1)
    end
  end
end
