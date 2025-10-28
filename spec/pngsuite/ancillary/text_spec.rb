# frozen_string_literal: true

require "spec_helper"
require_relative "../helpers/semantic_validator"

RSpec.describe "PngSuite Text (tEXt/zTXt/iTXt) Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../../fixtures/pngsuite/ancillary/text", __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates ct0n0g04.png" do
    fixture = File.join(fixtures_dir, "ct0n0g04.png")
    expected = File.join(expected_dir, "ct0n0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates ct1n0g04.png" do
    fixture = File.join(fixtures_dir, "ct1n0g04.png")
    expected = File.join(expected_dir, "ct1n0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates cten0g04.png" do
    fixture = File.join(fixtures_dir, "cten0g04.png")
    expected = File.join(expected_dir, "cten0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates ctfn0g04.png" do
    fixture = File.join(fixtures_dir, "ctfn0g04.png")
    expected = File.join(expected_dir, "ctfn0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates ctgn0g04.png" do
    fixture = File.join(fixtures_dir, "ctgn0g04.png")
    expected = File.join(expected_dir, "ctgn0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates cthn0g04.png" do
    fixture = File.join(fixtures_dir, "cthn0g04.png")
    expected = File.join(expected_dir, "cthn0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates ctjn0g04.png" do
    fixture = File.join(fixtures_dir, "ctjn0g04.png")
    expected = File.join(expected_dir, "ctjn0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates ctzn0g04.png" do
    fixture = File.join(fixtures_dir, "ctzn0g04.png")
    expected = File.join(expected_dir, "ctzn0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
