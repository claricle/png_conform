# frozen_string_literal: true

require "spec_helper"
require_relative "../helpers/semantic_validator"

RSpec.describe "PngSuite Histogram (hIST) Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../../fixtures/pngsuite/ancillary/histogram", __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates ch1n3p04.png" do
    fixture = File.join(fixtures_dir, "ch1n3p04.png")
    expected = File.join(expected_dir, "ch1n3p04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates ch2n3p08.png" do
    fixture = File.join(fixtures_dir, "ch2n3p08.png")
    expected = File.join(expected_dir, "ch2n3p08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
