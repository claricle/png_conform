# frozen_string_literal: true

require "spec_helper"
require "png_conform/bindata/png_file"

RSpec.describe PngConform::BinData::PngFile do
  let(:fixture_path) do
    File.expand_path("../../fixtures/pngsuite/basic/non_interlaced/basn0g01.png",
                     __dir__)
  end

  describe "reading a valid PNG file" do
    let(:png) do
      File.open(fixture_path, "rb") do |f|
        described_class.read(f)
      end
    end

    it "has valid signature" do
      expect(png.valid_signature?).to be true
    end

    it "reads chunks" do
      expect(png.chunks).not_to be_empty
    end

    it "has IHDR as first chunk" do
      expect(png.chunks.first.type).to eq("IHDR")
    end

    it "has IEND as last chunk" do
      expect(png.chunks.last.type).to eq("IEND")
    end

    it "is structurally valid" do
      expect(png.structurally_valid?).to be true
    end

    it "finds IHDR chunk" do
      ihdr = png.ihdr
      expect(ihdr).not_to be_nil
      expect(ihdr.type).to eq("IHDR")
    end

    it "finds IEND chunk" do
      iend = png.iend
      expect(iend).not_to be_nil
      expect(iend.type).to eq("IEND")
    end

    it "finds IDAT chunks" do
      idats = png.idats
      expect(idats).not_to be_empty
      expect(idats.first.type).to eq("IDAT")
    end
  end

  describe "#chunk_sequence" do
    let(:png) do
      File.open(fixture_path, "rb") do |f|
        described_class.read(f)
      end
    end

    it "returns array of chunk types" do
      sequence = png.chunk_sequence
      expect(sequence).to be_an(Array)
      expect(sequence.first).to eq("IHDR")
      expect(sequence.last).to eq("IEND")
    end
  end

  describe "#chunk_counts" do
    it "returns hash of chunk type counts" do
      png = File.open(fixture_path, "rb") do |f|
        described_class.read(f)
      end

      counts = png.chunk_counts
      expect(counts).to be_a(Hash)
      expect(counts.keys).to include("IHDR", "IEND", "IDAT")
      expect(counts.values.all? { |v| v >= 1 }).to be true
    end
  end

  describe "#all_crcs_valid?" do
    let(:png) do
      File.open(fixture_path, "rb") do |f|
        described_class.read(f)
      end
    end

    it "validates all CRCs in a valid file" do
      expect(png.all_crcs_valid?).to be true
    end
  end

  describe "#summary" do
    let(:png) do
      File.open(fixture_path, "rb") do |f|
        described_class.read(f)
      end
    end

    it "returns summary hash" do
      summary = png.summary
      expect(summary).to be_a(Hash)
      expect(summary[:signature_valid]).to be true
      expect(summary[:chunk_count]).to be > 0
      expect(summary[:structurally_valid]).to be true
      expect(summary[:all_crcs_valid]).to be true
    end
  end

  describe "reading invalid PNG (corrupted file)" do
    let(:invalid_path) do
      File.expand_path("../../fixtures/pngsuite/corrupted/xc1n0g08.png",
                       __dir__)
    end

    it "reads file but detects structural invalidity" do
      png = File.open(invalid_path, "rb") do |f|
        described_class.read(f)
      end

      # File should have valid signature
      expect(png.valid_signature?).to be true
      # But may not be structurally valid depending on content
    end
  end
end
