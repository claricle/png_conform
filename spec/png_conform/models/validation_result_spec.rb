# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::ValidationResult do
  let(:chunk) { instance_double(PngConform::Models::Chunk, type: "IHDR") }
  let(:error) { PngConform::Models::ValidationError.error("Test error") }
  let(:warning) { PngConform::Models::ValidationError.warning("Test warning") }
  let(:info) { PngConform::Models::ValidationError.info("Test info") }

  describe "constants" do
    it "defines file type constants" do
      expect(described_class::FILE_TYPE_PNG).to eq("PNG")
      expect(described_class::FILE_TYPE_MNG).to eq("MNG")
      expect(described_class::FILE_TYPE_JNG).to eq("JNG")
      expect(described_class::FILE_TYPE_UNKNOWN).to eq("UNKNOWN")
    end
  end

  describe "initialization" do
    it "initializes with default valid state" do
      result = described_class.new
      expect(result.valid).to be true
    end

    it "initializes with empty chunks array" do
      result = described_class.new
      expect(result.chunks).to eq([])
    end

    it "initializes with empty errors array" do
      result = described_class.new
      expect(result.errors).to eq([])
    end

    it "initializes with zero crc_errors_count" do
      result = described_class.new
      expect(result.crc_errors_count).to eq(0)
    end
  end

  describe "#add_chunk" do
    it "adds chunk to chunks collection" do
      result = described_class.new
      result.add_chunk(chunk)
      expect(result.chunks).to include(chunk)
    end

    it "allows adding multiple chunks" do
      result = described_class.new
      chunk2 = instance_double(PngConform::Models::Chunk, type: "IDAT")
      result.add_chunk(chunk)
      result.add_chunk(chunk2)
      expect(result.chunks.size).to eq(2)
    end
  end

  describe "#add_error" do
    it "adds error to errors collection" do
      result = described_class.new
      result.add_error(error)
      expect(result.errors).to include(error)
    end

    it "sets valid to false when adding error" do
      result = described_class.new
      result.add_error(error)
      expect(result.valid).to be false
    end

    it "does not change valid state for warnings" do
      result = described_class.new
      result.add_error(warning)
      expect(result.valid).to be true
    end

    it "does not change valid state for info" do
      result = described_class.new
      result.add_error(info)
      expect(result.valid).to be true
    end
  end

  describe "#error" do
    it "creates and adds error" do
      result = described_class.new
      result.error("Test message", chunk_type: "IDAT")
      expect(result.errors.size).to eq(1)
      expect(result.errors.first.severity).to eq("error")
      expect(result.errors.first.message).to eq("Test message")
    end

    it "sets valid to false" do
      result = described_class.new
      result.error("Test message")
      expect(result.valid).to be false
    end
  end

  describe "#warning" do
    it "creates and adds warning" do
      result = described_class.new
      result.warning("Test warning", chunk_type: "tEXt")
      expect(result.errors.size).to eq(1)
      expect(result.errors.first.severity).to eq("warning")
      expect(result.errors.first.message).to eq("Test warning")
    end

    it "does not change valid state" do
      result = described_class.new
      result.warning("Test warning")
      expect(result.valid).to be true
    end
  end

  describe "#info" do
    it "creates and adds info message" do
      result = described_class.new
      result.info("Test info")
      expect(result.errors.size).to eq(1)
      expect(result.errors.first.severity).to eq("info")
    end
  end

  describe "#valid?" do
    it "returns true when valid" do
      result = described_class.new(valid: true)
      expect(result.valid?).to be true
    end

    it "returns false when invalid" do
      result = described_class.new(valid: false)
      expect(result.valid?).to be false
    end
  end

  describe "#file_path" do
    it "is an alias for filename" do
      result = described_class.new(filename: "test.png")
      expect(result.file_path).to eq("test.png")
      expect(result.file_path).to eq(result.filename)
    end
  end

  describe "#error_messages" do
    it "returns only errors" do
      result = described_class.new
      result.add_error(error)
      result.add_error(warning)
      result.add_error(info)
      expect(result.error_messages.size).to eq(1)
      expect(result.error_messages.first).to eq(error)
    end
  end

  describe "#warning_messages" do
    it "returns only warnings" do
      result = described_class.new
      result.add_error(error)
      result.add_error(warning)
      result.add_error(info)
      expect(result.warning_messages.size).to eq(1)
      expect(result.warning_messages.first).to eq(warning)
    end
  end

  describe "#info_messages" do
    it "returns only info messages" do
      result = described_class.new
      result.add_error(error)
      result.add_error(warning)
      result.add_error(info)
      expect(result.info_messages.size).to eq(1)
      expect(result.info_messages.first).to eq(info)
    end
  end

  describe "#error_count" do
    it "counts only errors" do
      result = described_class.new
      result.add_error(error)
      result.add_error(warning)
      result.add_error(info)
      expect(result.error_count).to eq(1)
    end
  end

  describe "#warning_count" do
    it "counts only warnings" do
      result = described_class.new
      result.add_error(error)
      result.add_error(warning)
      result.add_error(warning)
      expect(result.warning_count).to eq(2)
    end
  end

  describe "#info_count" do
    it "counts only info messages" do
      result = described_class.new
      result.add_error(info)
      result.add_error(info)
      result.add_error(error)
      expect(result.info_count).to eq(2)
    end
  end

  describe "#chunk_count" do
    it "returns number of chunks" do
      result = described_class.new
      result.add_chunk(chunk)
      result.add_chunk(instance_double(PngConform::Models::Chunk, type: "IDAT"))
      expect(result.chunk_count).to eq(2)
    end
  end

  describe "#chunks_by_type" do
    it "filters chunks by type" do
      ihdr = instance_double(PngConform::Models::Chunk, type: "IHDR")
      idat1 = instance_double(PngConform::Models::Chunk, type: "IDAT")
      idat2 = instance_double(PngConform::Models::Chunk, type: "IDAT")
      result = described_class.new
      result.add_chunk(ihdr)
      result.add_chunk(idat1)
      result.add_chunk(idat2)

      idats = result.chunks_by_type("IDAT")
      expect(idats.size).to eq(2)
      expect(idats).to include(idat1, idat2)
    end

    it "returns empty array when no matches" do
      result = described_class.new
      result.add_chunk(chunk)
      expect(result.chunks_by_type("PLTE")).to eq([])
    end
  end

  describe "#has_chunk?" do
    it "returns true when chunk type exists" do
      result = described_class.new
      result.add_chunk(chunk)
      expect(result.has_chunk?("IHDR")).to be true
    end

    it "returns false when chunk type does not exist" do
      result = described_class.new
      result.add_chunk(chunk)
      expect(result.has_chunk?("PLTE")).to be false
    end
  end

  describe "#ihdr_chunk" do
    it "returns first IHDR chunk" do
      ihdr = instance_double(PngConform::Models::Chunk, type: "IHDR")
      result = described_class.new
      result.add_chunk(ihdr)
      expect(result.ihdr_chunk).to eq(ihdr)
    end

    it "returns nil when no IHDR chunk" do
      result = described_class.new
      expect(result.ihdr_chunk).to be_nil
    end
  end

  describe "#mhdr_chunk" do
    it "returns first MHDR chunk" do
      mhdr = instance_double(PngConform::Models::Chunk, type: "MHDR")
      result = described_class.new
      result.add_chunk(mhdr)
      expect(result.mhdr_chunk).to eq(mhdr)
    end

    it "returns nil when no MHDR chunk" do
      result = described_class.new
      expect(result.mhdr_chunk).to be_nil
    end
  end

  describe "#jhdr_chunk" do
    it "returns first JHDR chunk" do
      jhdr = instance_double(PngConform::Models::Chunk, type: "JHDR")
      result = described_class.new
      result.add_chunk(jhdr)
      expect(result.jhdr_chunk).to eq(jhdr)
    end

    it "returns nil when no JHDR chunk" do
      result = described_class.new
      expect(result.jhdr_chunk).to be_nil
    end
  end

  describe "#summary" do
    it "shows OK status for valid files" do
      result = described_class.new(
        filename: "test.png",
        file_type: "PNG",
        file_size: 1024,
        valid: true,
      )
      expect(result.summary).to include("OK:")
      expect(result.summary).to include("test.png")
    end

    it "shows ERRORS status for invalid files" do
      result = described_class.new(
        filename: "bad.png",
        file_type: "PNG",
        file_size: 512,
        valid: false,
      )
      result.error("Invalid signature")
      expect(result.summary).to include("ERRORS:")
      expect(result.summary).to include("bad.png")
    end

    it "includes counts" do
      result = described_class.new(
        filename: "test.png",
        file_type: "PNG",
        file_size: 2048,
      )
      result.add_chunk(chunk)
      result.error("Error 1")
      result.warning("Warning 1")

      summary = result.summary
      expect(summary).to include("1 chunks")
      expect(summary).to include("1 errors")
      expect(summary).to include("1 warnings")
    end
  end

  describe "#error_summary" do
    it "formats error summary" do
      result = described_class.new(filename: "bad.png")
      result.error("Invalid CRC")
      result.error("Missing IEND")

      summary = result.error_summary
      expect(summary).to include("ERROR: bad.png")
      expect(summary).to include("Invalid CRC")
      expect(summary).to include("Missing IEND")
    end
  end

  describe "attribute initialization" do
    it "accepts metadata attributes" do
      result = described_class.new(
        filename: "test.png",
        file_type: "PNG",
        file_size: 4096,
        valid: false,
      )

      expect(result.filename).to eq("test.png")
      expect(result.file_type).to eq("PNG")
      expect(result.file_size).to eq(4096)
      expect(result.valid).to be false
    end

    it "accepts collection attributes" do
      chunks = [chunk]
      errors = [error]
      result = described_class.new(
        chunks: chunks,
        errors: errors,
        compression_ratio: -42.5,
        crc_errors_count: 3,
      )

      expect(result.chunks).to eq(chunks)
      expect(result.errors).to eq(errors)
      expect(result.compression_ratio).to eq(-42.5)
      expect(result.crc_errors_count).to eq(3)
    end
  end
end
