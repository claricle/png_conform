# frozen_string_literal: true

require "spec_helper"
require_relative "../helpers/semantic_validator"

RSpec.describe "PngSuite Significant Bits (sBIT) Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../../fixtures/pngsuite/ancillary/significant_bits",
                     __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates cs3n2c16.png" do
    fixture = File.join(fixtures_dir, "cs3n2c16.png")
    expected = File.join(expected_dir, "cs3n2c16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates cs3n3p08.png" do
    fixture = File.join(fixtures_dir, "cs3n3p08.png")
    expected = File.join(expected_dir, "cs3n3p08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates cs5n2c08.png" do
    fixture = File.join(fixtures_dir, "cs5n2c08.png")
    expected = File.join(expected_dir, "cs5n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates cs5n3p08.png" do
    fixture = File.join(fixtures_dir, "cs5n3p08.png")
    expected = File.join(expected_dir, "cs5n3p08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates cs8n2c08.png" do
    fixture = File.join(fixtures_dir, "cs8n2c08.png")
    expected = File.join(expected_dir, "cs8n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates cs8n3p08.png" do
    fixture = File.join(fixtures_dir, "cs8n3p08.png")
    expected = File.join(expected_dir, "cs8n3p08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
