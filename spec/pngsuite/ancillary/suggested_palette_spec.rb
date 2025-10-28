# frozen_string_literal: true

require "spec_helper"
require_relative "../helpers/semantic_validator"

RSpec.describe "PngSuite Suggested Palette (sPLT) Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../../fixtures/pngsuite/ancillary/suggested_palette",
                     __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates ps1n0g08.png" do
    fixture = File.join(fixtures_dir, "ps1n0g08.png")
    expected = File.join(expected_dir, "ps1n0g08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates ps1n2c16.png" do
    fixture = File.join(fixtures_dir, "ps1n2c16.png")
    expected = File.join(expected_dir, "ps1n2c16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates ps2n0g08.png" do
    fixture = File.join(fixtures_dir, "ps2n0g08.png")
    expected = File.join(expected_dir, "ps2n0g08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates ps2n2c16.png" do
    fixture = File.join(fixtures_dir, "ps2n2c16.png")
    expected = File.join(expected_dir, "ps2n2c16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
