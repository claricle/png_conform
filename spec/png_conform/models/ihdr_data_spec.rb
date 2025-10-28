# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::IhdrData do
  describe "#color_type_name" do
    it "returns 'grayscale' for color type 0" do
      data = described_class.new(color_type: 0)
      expect(data.color_type_name).to eq("grayscale")
    end

    it "returns 'truecolor' for color type 2" do
      data = described_class.new(color_type: 2)
      expect(data.color_type_name).to eq("truecolor")
    end

    it "returns 'palette' for color type 3" do
      data = described_class.new(color_type: 3)
      expect(data.color_type_name).to eq("palette")
    end

    it "returns 'grayscale+alpha' for color type 4" do
      data = described_class.new(color_type: 4)
      expect(data.color_type_name).to eq("grayscale+alpha")
    end

    it "returns 'truecolor+alpha' for color type 6" do
      data = described_class.new(color_type: 6)
      expect(data.color_type_name).to eq("truecolor+alpha")
    end

    it "returns 'unknown' for invalid color type" do
      data = described_class.new(color_type: 99)
      expect(data.color_type_name).to eq("unknown")
    end
  end

  describe "#interlaced?" do
    it "returns true when interlace_method is 1" do
      data = described_class.new(interlace_method: 1)
      expect(data.interlaced?).to be true
    end

    it "returns false when interlace_method is 0" do
      data = described_class.new(interlace_method: 0)
      expect(data.interlaced?).to be false
    end
  end

  describe "#summary" do
    it "formats complete image information" do
      data = described_class.new(
        width: 1024,
        height: 768,
        bit_depth: 8,
        color_type: 2,
        interlace_method: 0,
      )
      expect(data.summary).to eq("1024 x 768 image, 8-bit truecolor, non-interlaced")
    end

    it "handles interlaced images" do
      data = described_class.new(
        width: 640,
        height: 480,
        bit_depth: 16,
        color_type: 6,
        interlace_method: 1,
      )
      expect(data.summary).to eq("640 x 480 image, 16-bit truecolor+alpha, interlaced")
    end
  end
end
