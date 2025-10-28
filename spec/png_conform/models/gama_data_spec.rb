# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::GamaData do
  describe "#summary" do
    it "formats gamma value to 4 decimal places" do
      data = described_class.new(gamma: 2.2)
      expect(data.summary).to eq("2.2000")
    end

    it "handles small gamma values" do
      data = described_class.new(gamma: 0.4545)
      expect(data.summary).to eq("0.4545")
    end
  end
end
