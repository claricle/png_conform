# frozen_string_literal: true

require "spec_helper"
require_relative "helpers/semantic_validator"

RSpec.describe "PngSuite Filter Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../fixtures/pngsuite/filters", __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates f00n0g08.png" do
    fixture = File.join(fixtures_dir, "f00n0g08.png")
    expected = File.join(expected_dir, "f00n0g08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates f00n2c08.png" do
    fixture = File.join(fixtures_dir, "f00n2c08.png")
    expected = File.join(expected_dir, "f00n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates f01n0g08.png" do
    fixture = File.join(fixtures_dir, "f01n0g08.png")
    expected = File.join(expected_dir, "f01n0g08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates f01n2c08.png" do
    fixture = File.join(fixtures_dir, "f01n2c08.png")
    expected = File.join(expected_dir, "f01n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates f02n0g08.png" do
    fixture = File.join(fixtures_dir, "f02n0g08.png")
    expected = File.join(expected_dir, "f02n0g08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates f02n2c08.png" do
    fixture = File.join(fixtures_dir, "f02n2c08.png")
    expected = File.join(expected_dir, "f02n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates f03n0g08.png" do
    fixture = File.join(fixtures_dir, "f03n0g08.png")
    expected = File.join(expected_dir, "f03n0g08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates f03n2c08.png" do
    fixture = File.join(fixtures_dir, "f03n2c08.png")
    expected = File.join(expected_dir, "f03n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates f04n0g08.png" do
    fixture = File.join(fixtures_dir, "f04n0g08.png")
    expected = File.join(expected_dir, "f04n0g08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates f04n2c08.png" do
    fixture = File.join(fixtures_dir, "f04n2c08.png")
    expected = File.join(expected_dir, "f04n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates f99n0g04.png" do
    fixture = File.join(fixtures_dir, "f99n0g04.png")
    expected = File.join(expected_dir, "f99n0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
