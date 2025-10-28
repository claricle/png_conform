# frozen_string_literal: true

require "spec_helper"
require "png_conform/bindata/chunk_structure"

RSpec.describe PngConform::BinData::ChunkStructure do
  describe "reading a chunk" do
    let(:chunk_data) do
      # IHDR chunk: length=13, type="IHDR", width=1, height=1, etc., CRC
      [
        0x00, 0x00, 0x00, 0x0D,                         # Length: 13
        0x49, 0x48, 0x44, 0x52,                         # Type: "IHDR"
        0x00, 0x00, 0x00, 0x01,                         # Width: 1
        0x00, 0x00, 0x00, 0x01,                         # Height: 1
        0x01, 0x00, 0x00, 0x00, 0x00,                   # Bit depth, color, etc.
        0x37, 0x6E, 0xF9, 0x24                          # CRC
      ].pack("C*")
    end

    let(:chunk) { described_class.read(StringIO.new(chunk_data)) }

    it "reads the length correctly" do
      expect(chunk.length).to eq(13)
    end

    it "reads the type correctly" do
      expect(chunk.type).to eq("IHDR")
    end

    it "reads the data with correct length" do
      expect(chunk.data.length).to eq(13)
    end

    it "reads the CRC" do
      expect(chunk.crc).to eq(0x376ef924)
    end

    it "validates CRC correctly" do
      expect(chunk.crc_valid?).to be true
    end
  end

  describe "#type_symbol" do
    let(:chunk_data) do
      [
        0x00, 0x00, 0x00, 0x00,           # Length: 0
        0x49, 0x45, 0x4E, 0x44,           # Type: "IEND"
        0xAE, 0x42, 0x60, 0x82            # CRC
      ].pack("C*")
    end

    let(:chunk) { described_class.read(StringIO.new(chunk_data)) }

    it "returns type as symbol" do
      expect(chunk.type_symbol).to eq(:IEND)
    end
  end

  describe "chunk type properties" do
    describe "critical chunk (IHDR)" do
      let(:chunk_data) do
        [
          0x00, 0x00, 0x00, 0x0D,
          0x49, 0x48, 0x44, 0x52,
          *([0] * 13),
          0x00, 0x00, 0x00, 0x00
        ].pack("C*")
      end

      let(:chunk) { described_class.read(StringIO.new(chunk_data)) }

      it "is identified as critical" do
        expect(chunk.critical?).to be true
      end

      it "is not ancillary" do
        expect(chunk.ancillary?).to be false
      end
    end

    describe "ancillary chunk (tEXt)" do
      let(:chunk_data) do
        [
          0x00, 0x00, 0x00, 0x00,
          0x74, 0x45, 0x58, 0x74,           # "tEXt"
          0x00, 0x00, 0x00, 0x00
        ].pack("C*")
      end

      let(:chunk) { described_class.read(StringIO.new(chunk_data)) }

      it "is identified as ancillary" do
        expect(chunk.ancillary?).to be true
      end

      it "is not critical" do
        expect(chunk.critical?).to be false
      end
    end

    describe "safe to copy" do
      let(:safe_chunk_data) do
        [
          0x00, 0x00, 0x00, 0x00,
          0x74, 0x45, 0x58, 0x74,           # "tEXt" (lowercase 't' = safe)
          0x00, 0x00, 0x00, 0x00
        ].pack("C*")
      end

      let(:unsafe_chunk_data) do
        [
          0x00, 0x00, 0x00, 0x00,
          0x74, 0x45, 0x58, 0x54,           # "tEXT" (uppercase 'T' = unsafe)
          0x00, 0x00, 0x00, 0x00
        ].pack("C*")
      end

      it "identifies safe-to-copy chunks" do
        chunk = described_class.read(StringIO.new(safe_chunk_data))
        expect(chunk.safe_to_copy?).to be true
      end

      it "identifies unsafe-to-copy chunks" do
        chunk = described_class.read(StringIO.new(unsafe_chunk_data))
        expect(chunk.safe_to_copy?).to be false
      end
    end
  end

  describe "#to_s" do
    let(:chunk_data) do
      [
        0x00, 0x00, 0x00, 0x00,
        0x49, 0x45, 0x4E, 0x44,
        0xAE, 0x42, 0x60, 0x82
      ].pack("C*")
    end

    let(:chunk) { described_class.read(StringIO.new(chunk_data)) }

    it "returns formatted chunk information" do
      expect(chunk.to_s).to include("IEND")
      expect(chunk.to_s).to include("0 bytes")
      expect(chunk.to_s).to include("0xae426082")
    end
  end

  describe "#inspect_details" do
    let(:chunk_data) do
      [
        0x00, 0x00, 0x00, 0x00,
        0x49, 0x45, 0x4E, 0x44,
        0xAE, 0x42, 0x60, 0x82
      ].pack("C*")
    end

    let(:chunk) { described_class.read(StringIO.new(chunk_data)) }

    it "returns hash with chunk details" do
      details = chunk.inspect_details
      expect(details).to be_a(Hash)
      expect(details[:type]).to eq("IEND")
      expect(details[:length]).to eq(0)
      expect(details[:crc_valid]).to be true
      expect(details[:critical]).to be true
    end
  end
end
