# frozen_string_literal: true

require "spec_helper"
require_relative "helpers/semantic_validator"

RSpec.describe "PngSuite Compression Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../fixtures/pngsuite/compression", __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates z00n2c08.png" do
    fixture = File.join(fixtures_dir, "z00n2c08.png")
    expected = File.join(expected_dir, "z00n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates z03n2c08.png" do
    fixture = File.join(fixtures_dir, "z03n2c08.png")
    expected = File.join(expected_dir, "z03n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates z06n2c08.png" do
    fixture = File.join(fixtures_dir, "z06n2c08.png")
    expected = File.join(expected_dir, "z06n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates z09n2c08.png" do
    fixture = File.join(fixtures_dir, "z09n2c08.png")
    expected = File.join(expected_dir, "z09n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
