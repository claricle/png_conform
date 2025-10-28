# frozen_string_literal: true

require "spec_helper"
require_relative "../helpers/semantic_validator"

RSpec.describe "PngSuite Physical Dimensions (pHYs) Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../../fixtures/pngsuite/ancillary/physical_dims", __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates cdfn2c08.png" do
    fixture = File.join(fixtures_dir, "cdfn2c08.png")
    expected = File.join(expected_dir, "cdfn2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates cdhn2c08.png" do
    fixture = File.join(fixtures_dir, "cdhn2c08.png")
    expected = File.join(expected_dir, "cdhn2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates cdsn2c08.png" do
    fixture = File.join(fixtures_dir, "cdsn2c08.png")
    expected = File.join(expected_dir, "cdsn2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates cdun2c08.png" do
    fixture = File.join(fixtures_dir, "cdun2c08.png")
    expected = File.join(expected_dir, "cdun2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
