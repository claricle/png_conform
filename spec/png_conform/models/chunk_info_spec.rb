# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::ChunkInfo do
  describe ".new" do
    it "initializes with attributes" do
      chunk = described_class.new(
        type: "IHDR",
        offset: 8,
        length: 13,
        crc_valid: true,
        critical: true,
        private: false,
        safe_to_copy: false,
      )

      expect(chunk.type).to eq("IHDR")
      expect(chunk.offset).to eq(8)
      expect(chunk.length).to eq(13)
      expect(chunk.crc_valid).to be true
      expect(chunk.critical).to be true
      expect(chunk.private).to be false
      expect(chunk.safe_to_copy).to be false
    end

    it "handles binary data fields separately" do
      data = "binary data".b
      crc = "\x00\x01\x02\x03".b

      chunk = described_class.new(
        type: "IDAT",
        data: data,
        crc: crc,
      )

      expect(chunk.data).to eq(data)
      expect(chunk.crc).to eq(crc)
    end

    it "accepts decoded_data" do
      decoded_data = instance_double(PngConform::Models::DecodedChunkData)
      chunk = described_class.new(
        type: "IHDR",
        decoded_data: decoded_data,
      )

      expect(chunk.decoded_data).to eq(decoded_data)
    end
  end

  describe "#offset_hex" do
    it "formats offset as hex string" do
      chunk = described_class.new(offset: 8)
      expect(chunk.offset_hex).to eq("0x00008")
    end

    it "handles larger offsets" do
      chunk = described_class.new(offset: 4096)
      expect(chunk.offset_hex).to eq("0x01000")
    end

    it "handles zero offset" do
      chunk = described_class.new(offset: 0)
      expect(chunk.offset_hex).to eq("0x00000")
    end
  end

  describe "#properties" do
    it "returns critical for critical chunks" do
      chunk = described_class.new(critical: true)
      expect(chunk.properties).to include("critical")
    end

    it "returns ancillary for non-critical chunks" do
      chunk = described_class.new(critical: false)
      expect(chunk.properties).to include("ancillary")
    end

    it "returns private when private is true" do
      chunk = described_class.new(private: true)
      expect(chunk.properties).to include("private")
    end

    it "returns safe-to-copy when safe_to_copy is true" do
      chunk = described_class.new(safe_to_copy: true)
      expect(chunk.properties).to include("safe-to-copy")
    end

    it "returns multiple properties" do
      chunk = described_class.new(
        critical: true,
        private: true,
        safe_to_copy: true,
      )
      properties = chunk.properties
      expect(properties).to include("critical")
      expect(properties).to include("private")
      expect(properties).to include("safe-to-copy")
    end
  end

  describe "#summary" do
    it "formats chunk summary" do
      chunk = described_class.new(
        type: "IHDR",
        offset: 8,
        length: 13,
      )
      expect(chunk.summary).to eq("chunk IHDR at offset 0x00008, length 13")
    end
  end

  describe "#detailed_summary" do
    it "returns summary when no decoded_data" do
      chunk = described_class.new(
        type: "IHDR",
        offset: 8,
        length: 13,
      )
      expect(chunk.detailed_summary).to eq(chunk.summary)
    end

    it "includes decoded_data summary when present" do
      decoded_data = instance_double(
        PngConform::Models::DecodedChunkData,
        summary: "1024 x 768 image",
      )
      chunk = described_class.new(
        type: "IHDR",
        offset: 8,
        length: 13,
        decoded_data: decoded_data,
      )

      expected = "chunk IHDR at offset 0x00008, length 13\n    1024 x 768 image"
      expect(chunk.detailed_summary).to eq(expected)
    end
  end

  describe "#chunk_type" do
    it "is an alias for type" do
      chunk = described_class.new(type: "PLTE")
      expect(chunk.chunk_type).to eq("PLTE")
      expect(chunk.chunk_type).to eq(chunk.type)
    end
  end

  describe "#abs_offset" do
    it "is an alias for offset" do
      chunk = described_class.new(offset: 1024)
      expect(chunk.abs_offset).to eq(1024)
      expect(chunk.abs_offset).to eq(chunk.offset)
    end
  end

  describe "#chunk_data" do
    it "returns data with binary encoding" do
      data = "test data"
      chunk = described_class.new(data: data)
      result = chunk.chunk_data
      expect(result).to eq(data.b)
      expect(result.encoding).to eq(Encoding::BINARY)
    end

    it "returns nil when data is nil" do
      chunk = described_class.new
      expect(chunk.chunk_data).to be_nil
    end
  end

  describe "#crc_valid?" do
    it "returns true when crc_valid is true" do
      chunk = described_class.new(crc_valid: true)
      expect(chunk.crc_valid?).to be true
    end

    it "returns false when crc_valid is false" do
      chunk = described_class.new(crc_valid: false)
      expect(chunk.crc_valid?).to be false
    end

    it "returns nil when crc_valid is not set" do
      chunk = described_class.new
      expect(chunk.crc_valid?).to be_nil
    end
  end
end
