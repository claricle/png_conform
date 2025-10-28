# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::DecodedChunkData do
  describe "#summary" do
    it "returns empty string by default" do
      data = described_class.new
      expect(data.summary).to eq("")
    end
  end
end
