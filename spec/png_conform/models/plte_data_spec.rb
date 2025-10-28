# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::PlteData do
  describe "#summary" do
    it "returns count of palette entries" do
      entries = [
        PngConform::Models::PaletteEntry.new(red: 255, green: 0, blue: 0),
        PngConform::Models::PaletteEntry.new(red: 0, green: 255, blue: 0),
        PngConform::Models::PaletteEntry.new(red: 0, green: 0, blue: 255),
      ]
      data = described_class.new(entries: entries)
      expect(data.summary).to eq("3 palette entries")
    end

    it "returns 0 when entries is nil" do
      data = described_class.new
      expect(data.summary).to eq("0 palette entries")
    end

    it "returns 0 for empty entries" do
      data = described_class.new(entries: [])
      expect(data.summary).to eq("0 palette entries")
    end
  end

  describe "#detailed_entries" do
    it "returns empty array when entries is nil" do
      data = described_class.new
      expect(data.detailed_entries).to eq([])
    end

    it "formats each palette entry" do
      entries = [
        PngConform::Models::PaletteEntry.new(red: 255, green: 128, blue: 64),
        PngConform::Models::PaletteEntry.new(red: 0, green: 0, blue: 0),
      ]
      data = described_class.new(entries: entries)
      formatted = data.detailed_entries

      expect(formatted[0]).to match(/\s*0:\s+\(255,128,\s*64\)\s+=\s+\(0xff,0x80,0x40\)/)
      expect(formatted[1]).to match(/\s*1:\s+\(\s*0,\s*0,\s*0\)\s+=\s+\(0x00,0x00,0x00\)/)
    end
  end
end
