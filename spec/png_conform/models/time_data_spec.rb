# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::TimeData do
  describe "#summary" do
    it "formats timestamp" do
      data = described_class.new(
        year: 2024,
        month: 3,
        day: 15,
        hour: 14,
        minute: 30,
        second: 45,
      )
      expect(data.summary).to eq("2024-03-15 14:30:45")
    end

    it "handles single-digit values with zero padding" do
      data = described_class.new(
        year: 2024,
        month: 1,
        day: 5,
        hour: 9,
        minute: 8,
        second: 7,
      )
      expect(data.summary).to eq("2024-01-05 09:08:07")
    end
  end
end
