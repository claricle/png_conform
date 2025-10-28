# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::ImageInfo do
  describe ".color_type_name" do
    it "returns 'grayscale' for code 0" do
      expect(described_class.color_type_name(0)).to eq("grayscale")
    end

    it "returns 'truecolor' for code 2" do
      expect(described_class.color_type_name(2)).to eq("truecolor")
    end

    it "returns 'palette' for code 3" do
      expect(described_class.color_type_name(3)).to eq("palette")
    end

    it "returns 'grayscale+alpha' for code 4" do
      expect(described_class.color_type_name(4)).to eq("grayscale+alpha")
    end

    it "returns 'truecolor+alpha' for code 6" do
      expect(described_class.color_type_name(6)).to eq("truecolor+alpha")
    end

    it "returns 'unknown' for invalid code" do
      expect(described_class.color_type_name(99)).to eq("unknown")
    end
  end

  describe "#summary" do
    it "formats complete image information" do
      info = described_class.new(
        width: 1024,
        height: 768,
        bit_depth: 8,
        color_type: "truecolor",
        interlaced: false,
        animated: false,
      )
      expect(info.summary).to eq("1024x768, 8-bit truecolor, non-interlaced, static")
    end

    it "shows interlaced for interlaced images" do
      info = described_class.new(
        width: 640,
        height: 480,
        bit_depth: 16,
        color_type: "truecolor+alpha",
        interlaced: true,
        animated: false,
      )
      expect(info.summary).to eq("640x480, 16-bit truecolor+alpha, interlaced, static")
    end

    it "shows animated for animated images" do
      info = described_class.new(
        width: 320,
        height: 240,
        bit_depth: 8,
        color_type: "palette",
        interlaced: false,
        animated: true,
      )
      expect(info.summary).to eq("320x240, 8-bit palette, non-interlaced, animated")
    end

    it "handles interlaced and animated" do
      info = described_class.new(
        width: 800,
        height: 600,
        bit_depth: 8,
        color_type: "grayscale",
        interlaced: true,
        animated: true,
      )
      expect(info.summary).to eq("800x600, 8-bit grayscale, interlaced, animated")
    end

    it "handles small images" do
      info = described_class.new(
        width: 32,
        height: 32,
        bit_depth: 1,
        color_type: "grayscale",
        interlaced: false,
        animated: false,
      )
      expect(info.summary).to eq("32x32, 1-bit grayscale, non-interlaced, static")
    end
  end

  describe "attribute initialization" do
    it "accepts all attributes" do
      info = described_class.new(
        width: 1920,
        height: 1080,
        bit_depth: 16,
        color_type: "truecolor+alpha",
        interlaced: true,
        animated: false,
      )

      expect(info.width).to eq(1920)
      expect(info.height).to eq(1080)
      expect(info.bit_depth).to eq(16)
      expect(info.color_type).to eq("truecolor+alpha")
      expect(info.interlaced).to be true
      expect(info.animated).to be false
    end
  end
end
