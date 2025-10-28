# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::IdatData do
  describe "#summary" do
    it "formats basic zlib information" do
      data = described_class.new(
        compression_method: 8,
        window_bits: 32,
        compression_level: "default",
      )
      expect(data.summary).to include("zlib: deflated")
      expect(data.summary).to include("32K window")
      expect(data.summary).to include("default compression")
    end

    it "handles missing window_bits" do
      data = described_class.new(
        compression_level: "maximum",
      )
      summary = data.summary
      expect(summary).to include("zlib: deflated")
      expect(summary).not_to include("window")
      expect(summary).to include("maximum compression")
    end

    it "handles missing compression_level" do
      data = described_class.new(
        window_bits: 32,
      )
      summary = data.summary
      expect(summary).to include("zlib: deflated")
      expect(summary).to include("32K window")
    end
  end

  describe "#filter_summary" do
    it "returns nil when row_filters is nil" do
      data = described_class.new
      expect(data.filter_summary).to be_nil
    end

    it "returns nil when row_filters is empty" do
      data = described_class.new(row_filters: [])
      expect(data.filter_summary).to be_nil
    end

    it "formats row filters with names" do
      data = described_class.new(row_filters: [0, 1, 2, 3, 4])
      summary = data.filter_summary
      expect(summary).to include("row filters")
      expect(summary).to include("0 1 2 3 4")
    end
  end
end
