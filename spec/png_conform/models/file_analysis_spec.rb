# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::FileAnalysis do
  let(:validation_result) do
    instance_double(
      PngConform::Models::ValidationResult,
      valid?: true,
      error_summary: "ERROR: test.png\n  Invalid CRC",
      chunks: [],
      chunk_count: 0,
    )
  end

  let(:image_info) do
    instance_double(
      PngConform::Models::ImageInfo,
      summary: "32x32, 8-bit truecolor, non-interlaced, static",
    )
  end

  let(:compression_info) do
    instance_double(
      PngConform::Models::CompressionInfo,
      summary: "-28.1%",
      compression_ratio: -28.1,
    )
  end

  describe "#chunk_count" do
    it "returns number of chunks" do
      chunks = [
        instance_double(PngConform::Models::Chunk, type: "IHDR"),
        instance_double(PngConform::Models::Chunk, type: "IDAT"),
        instance_double(PngConform::Models::Chunk, type: "IEND"),
      ]
      result = instance_double(
        PngConform::Models::ValidationResult,
        chunks: chunks,
        chunk_count: 3,
      )
      analysis = described_class.new(validation_result: result)
      expect(analysis.chunk_count).to eq(3)
    end

    it "returns 0 when chunks is nil" do
      analysis = described_class.new
      expect(analysis.chunk_count).to eq(0)
    end

    it "returns 0 for empty chunks" do
      analysis = described_class.new(chunks: [])
      expect(analysis.chunk_count).to eq(0)
    end
  end

  describe "#valid?" do
    it "returns true when validation_result is valid" do
      valid_result = instance_double(
        PngConform::Models::ValidationResult,
        valid?: true,
      )
      analysis = described_class.new(validation_result: valid_result)
      expect(analysis.valid?).to be true
    end

    it "returns false when validation_result is invalid" do
      invalid_result = instance_double(
        PngConform::Models::ValidationResult,
        valid?: false,
      )
      analysis = described_class.new(validation_result: invalid_result)
      expect(analysis.valid?).to be false
    end

    it "returns false when validation_result is nil" do
      analysis = described_class.new
      expect(analysis.valid?).to be false
    end
  end

  describe "#status" do
    it "returns 'OK' for valid files" do
      valid_result = instance_double(
        PngConform::Models::ValidationResult,
        valid?: true,
      )
      analysis = described_class.new(validation_result: valid_result)
      expect(analysis.status).to eq("OK")
    end

    it "returns 'ERROR' for invalid files" do
      invalid_result = instance_double(
        PngConform::Models::ValidationResult,
        valid?: false,
      )
      analysis = described_class.new(validation_result: invalid_result)
      expect(analysis.status).to eq("ERROR")
    end
  end

  describe "#file_header" do
    it "formats file header with path and size" do
      analysis = described_class.new(
        file_path: "test.png",
        file_size: 1024,
      )
      expect(analysis.file_header).to eq("File: test.png (1024 bytes)")
    end
  end

  describe "#summary_line" do
    it "formats summary with all components" do
      analysis = described_class.new(
        file_path: "test.png",
        validation_result: validation_result,
        image_info: image_info,
        compression_info: compression_info,
      )

      summary = analysis.summary_line
      expect(summary).to eq("OK: test.png (32x32, 8-bit truecolor, non-interlaced, static, -28.1%).")
    end

    it "handles missing compression_info" do
      analysis = described_class.new(
        file_path: "test.png",
        validation_result: validation_result,
        image_info: image_info,
      )

      summary = analysis.summary_line
      expect(summary).to eq("OK: test.png (32x32, 8-bit truecolor, non-interlaced, static).")
    end

    it "handles missing image_info" do
      analysis = described_class.new(
        file_path: "test.png",
        validation_result: validation_result,
      )

      summary = analysis.summary_line
      expect(summary).to eq("OK: test.png.")
    end

    it "shows ERROR status for invalid files" do
      invalid_result = instance_double(
        PngConform::Models::ValidationResult,
        valid?: false,
      )
      analysis = described_class.new(
        file_path: "bad.png",
        validation_result: invalid_result,
        image_info: image_info,
      )

      summary = analysis.summary_line
      expect(summary).to start_with("ERROR:")
    end
  end

  describe "#validation_summary" do
    it "returns error summary for invalid files" do
      invalid_result = instance_double(
        PngConform::Models::ValidationResult,
        valid?: false,
        error_summary: "ERROR: bad.png\n  Invalid signature",
      )
      analysis = described_class.new(
        file_path: "bad.png",
        validation_result: invalid_result,
      )

      expect(analysis.validation_summary).to eq("ERROR: bad.png\n  Invalid signature")
    end

    it "returns success message for valid files" do
      chunks = Array.new(4) { instance_double(PngConform::Models::Chunk, type: "IDAT") }
      result = instance_double(
        PngConform::Models::ValidationResult,
        valid?: true,
        error_summary: "",
        chunks: chunks,
        chunk_count: 4,
      )
      analysis = described_class.new(
        file_path: "test.png",
        validation_result: result,
        compression_info: compression_info,
      )

      summary = analysis.validation_summary
      expect(summary).to include("No errors detected in test.png")
      expect(summary).to include("4 chunks")
      expect(summary).to include("-28.1% compression")
    end

    it "handles missing compression_info" do
      chunks = Array.new(2) { instance_double(PngConform::Models::Chunk, type: "IDAT") }
      result = instance_double(
        PngConform::Models::ValidationResult,
        valid?: true,
        error_summary: "",
        chunks: chunks,
        chunk_count: 2,
      )
      analysis = described_class.new(
        file_path: "test.png",
        validation_result: result,
      )

      summary = analysis.validation_summary
      expect(summary).to include("No errors detected in test.png")
      expect(summary).to include("2 chunks")
      expect(summary).not_to include("compression")
    end

    it "handles zero chunks" do
      result = instance_double(
        PngConform::Models::ValidationResult,
        valid?: true,
        error_summary: "",
        chunks: [],
        chunk_count: 0,
      )
      analysis = described_class.new(
        file_path: "test.png",
        validation_result: result,
      )

      summary = analysis.validation_summary
      expect(summary).to eq("No errors detected in test.png.")
    end
  end

  describe "#filename" do
    it "is an alias for file_path" do
      analysis = described_class.new(file_path: "image.png")
      expect(analysis.filename).to eq("image.png")
      expect(analysis.filename).to eq(analysis.file_path)
    end
  end

  describe "#errors" do
    it "delegates to validation_result" do
      errors = [
        instance_double(PngConform::Models::ValidationError),
        instance_double(PngConform::Models::ValidationError),
      ]
      result = instance_double(
        PngConform::Models::ValidationResult,
        errors: errors,
      )
      analysis = described_class.new(validation_result: result)
      expect(analysis.errors).to eq(errors)
    end

    it "returns empty array when validation_result is nil" do
      analysis = described_class.new
      expect(analysis.errors).to eq([])
    end
  end

  describe "#compression_ratio" do
    it "delegates to compression_info" do
      analysis = described_class.new(compression_info: compression_info)
      expect(analysis.compression_ratio).to eq(-28.1)
    end

    it "returns nil when compression_info is nil" do
      analysis = described_class.new
      expect(analysis.compression_ratio).to be_nil
    end
  end

  describe "attribute initialization" do
    it "accepts all attributes" do
      result = instance_double(
        PngConform::Models::ValidationResult,
        chunks: [],
      )
      analysis = described_class.new(
        file_path: "test.png",
        file_size: 2048,
        file_type: "PNG",
        validation_result: result,
        image_info: image_info,
        compression_info: compression_info,
      )

      expect(analysis.file_path).to eq("test.png")
      expect(analysis.file_size).to eq(2048)
      expect(analysis.file_type).to eq("PNG")
      expect(analysis.validation_result).to eq(result)
      expect(analysis.chunks).to eq([])
      expect(analysis.image_info).to eq(image_info)
      expect(analysis.compression_info).to eq(compression_info)
    end
  end
end
