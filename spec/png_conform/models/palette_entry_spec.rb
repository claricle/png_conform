# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::PaletteEntry do
  describe "initialization" do
    it "accepts RGB values" do
      entry = described_class.new(red: 255, green: 128, blue: 64)
      expect(entry.red).to eq(255)
      expect(entry.green).to eq(128)
      expect(entry.blue).to eq(64)
    end
  end
end
