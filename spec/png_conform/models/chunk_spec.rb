# frozen_string_literal: true

require "spec_helper"
require "png_conform/models/chunk"

RSpec.describe PngConform::Models::Chunk do
  describe ".from_bindata" do
    let(:bindata_chunk) do
      double(
        type: "IHDR",
        length: 13,
        data: "\x00" * 13,
        crc: 0x12345678,
      )
    end

    it "creates chunk from BinData structure" do
      chunk = described_class.from_bindata(bindata_chunk, 100)

      expect(chunk.type).to eq("IHDR")
      expect(chunk.length).to eq(13)
      expect(chunk.data).to eq("\x00" * 13)
      expect(chunk.crc).to eq(0x12345678)
      expect(chunk.offset).to eq(100)
    end

    it "sets offset to 0 when not provided" do
      chunk = described_class.from_bindata(bindata_chunk)

      expect(chunk.offset).to eq(0)
    end
  end

  describe "#critical?" do
    it "returns true for critical chunks (uppercase first letter)" do
      chunk = described_class.new(type: "IHDR")
      expect(chunk.critical?).to be true
    end

    it "returns false for ancillary chunks (lowercase first letter)" do
      chunk = described_class.new(type: "tEXt")
      expect(chunk.critical?).to be false
    end
  end

  describe "#ancillary?" do
    it "returns false for critical chunks" do
      chunk = described_class.new(type: "PLTE")
      expect(chunk.ancillary?).to be false
    end

    it "returns true for ancillary chunks" do
      chunk = described_class.new(type: "gAMA")
      expect(chunk.ancillary?).to be true
    end
  end

  describe "#public?" do
    it "returns true for public chunks (uppercase second letter)" do
      chunk = described_class.new(type: "IHDR")
      expect(chunk.public?).to be true
    end

    it "returns false for private chunks (lowercase second letter)" do
      chunk = described_class.new(type: "prVt")
      expect(chunk.public?).to be false
    end
  end

  describe "#private?" do
    it "returns false for public chunks" do
      chunk = described_class.new(type: "PLTE")
      expect(chunk.private?).to be false
    end

    it "returns true for private chunks" do
      chunk = described_class.new(type: "prVt")
      expect(chunk.private?).to be true
    end
  end

  describe "#reserved?" do
    it "returns true for reserved chunks (uppercase third letter)" do
      chunk = described_class.new(type: "IHDR")
      expect(chunk.reserved?).to be true
    end

    it "returns false for non-reserved chunks (lowercase third letter)" do
      chunk = described_class.new(type: "IHdR")
      expect(chunk.reserved?).to be false
    end
  end

  describe "#safe_to_copy?" do
    it "returns true for safe-to-copy chunks (lowercase fourth letter)" do
      chunk = described_class.new(type: "tEXt")
      expect(chunk.safe_to_copy?).to be true
    end

    it "returns false for unsafe-to-copy chunks (uppercase fourth letter)" do
      chunk = described_class.new(type: "tEXT")
      expect(chunk.safe_to_copy?).to be false
    end
  end

  describe "#type_symbol" do
    it "returns type as symbol" do
      chunk = described_class.new(type: "IHDR")
      expect(chunk.type_symbol).to eq(:IHDR)
    end
  end

  describe "#total_size" do
    it "calculates total chunk size including header and CRC" do
      chunk = described_class.new(length: 13)
      # 4 (length field) + 4 (type field) + 13 (data) + 4 (CRC) = 25
      expect(chunk.total_size).to eq(25)
    end

    it "calculates size for zero-length chunk" do
      chunk = described_class.new(length: 0)
      # 4 + 4 + 0 + 4 = 12
      expect(chunk.total_size).to eq(12)
    end
  end

  describe "#offset_hex" do
    it "formats offset as hexadecimal with 0x prefix" do
      chunk = described_class.new(offset: 256)
      expect(chunk.offset_hex).to eq("0x00100")
    end

    it "formats zero offset" do
      chunk = described_class.new(offset: 0)
      expect(chunk.offset_hex).to eq("0x00000")
    end

    it "formats large offset" do
      chunk = described_class.new(offset: 1_048_576)
      expect(chunk.offset_hex).to eq("0x100000")
    end
  end

  describe "CRC validation methods" do
    describe "#crc_valid?" do
      it "returns value of valid_crc attribute" do
        chunk = described_class.new(valid_crc: true)
        expect(chunk.crc_valid?).to be true
      end

      it "returns false when not valid" do
        chunk = described_class.new(valid_crc: false)
        expect(chunk.crc_valid?).to be false
      end
    end

    describe "#valid_crc?" do
      it "returns value of valid_crc attribute" do
        chunk = described_class.new(valid_crc: true)
        expect(chunk.valid_crc?).to be true
      end
    end
  end

  describe "attribute defaults" do
    it "sets valid_crc to false by default" do
      chunk = described_class.new
      expect(chunk.valid_crc).to be false
    end
  end
end
