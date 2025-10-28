# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::CompressionInfo do
  describe ".calculate_ratio" do
    it "calculates compression ratio from sizes" do
      ratio = described_class.calculate_ratio(1000, 600)
      expect(ratio).to be_within(0.01).of(-40.0)
    end

    it "returns 0.0 when uncompressed size is zero" do
      ratio = described_class.calculate_ratio(0, 100)
      expect(ratio).to eq(0.0)
    end

    it "handles perfect compression" do
      ratio = described_class.calculate_ratio(1000, 0)
      expect(ratio).to be_within(0.01).of(-100.0)
    end

    it "handles expansion (negative compression)" do
      ratio = described_class.calculate_ratio(100, 150)
      expect(ratio).to be_within(0.01).of(50.0)
    end
  end

  describe "#level_name" do
    it "returns the compression level name directly" do
      info = described_class.new(compression_level: "fastest")
      expect(info.level_name).to eq("custom")
    end

    it "returns 'custom' for any string value" do
      info = described_class.new(compression_level: "default")
      expect(info.level_name).to eq("custom")
    end

    it "returns 'custom' when compression_level is nil" do
      info = described_class.new
      expect(info.level_name).to eq("custom")
    end
  end

  describe "#summary" do
    it "formats compression ratio as percentage" do
      info = described_class.new(compression_ratio: -42.5)
      expect(info.summary).to eq("-42.5%")
    end

    it "handles positive ratios (expansion)" do
      info = described_class.new(compression_ratio: 15.3)
      expect(info.summary).to eq("15.3%")
    end

    it "formats zero ratio" do
      info = described_class.new(compression_ratio: 0.0)
      expect(info.summary).to eq("0.0%")
    end
  end

  describe "#details" do
    it "includes deflated method" do
      info = described_class.new
      expect(info.details).to include("deflated")
    end

    it "includes window bits when present" do
      info = described_class.new(window_bits: 32)
      expect(info.details).to include("32K window")
    end

    it "includes compression level name" do
      info = described_class.new(compression_level: "maximum")
      expect(info.details).to include("custom compression")
    end

    it "combines all components" do
      info = described_class.new(
        window_bits: 32,
        compression_level: "default",
      )
      details = info.details
      expect(details).to include("deflated")
      expect(details).to include("32K window")
      expect(details).to include("custom compression")
    end

    it "omits window bits when not present" do
      info = described_class.new(compression_level: "maximum")
      expect(info.details).not_to include("window")
    end
  end

  describe "attribute initialization" do
    it "accepts all attributes" do
      info = described_class.new(
        uncompressed_size: 10_000,
        compressed_size: 6000,
        compression_ratio: -40.0,
        window_bits: 32,
        compression_level: "default",
      )

      expect(info.uncompressed_size).to eq(10_000)
      expect(info.compressed_size).to eq(6000)
      expect(info.compression_ratio).to eq(-40.0)
      expect(info.window_bits).to eq(32)
      expect(info.compression_level).to eq("default")
    end
  end
end
