# frozen_string_literal: true

require "spec_helper"
require_relative "helpers/semantic_validator"

RSpec.describe "PngSuite Chunk Ordering Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../fixtures/pngsuite/ordering", __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates oi1n0g16.png" do
    fixture = File.join(fixtures_dir, "oi1n0g16.png")
    expected = File.join(expected_dir, "oi1n0g16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates oi1n2c16.png" do
    fixture = File.join(fixtures_dir, "oi1n2c16.png")
    expected = File.join(expected_dir, "oi1n2c16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates oi2n0g16.png" do
    fixture = File.join(fixtures_dir, "oi2n0g16.png")
    expected = File.join(expected_dir, "oi2n0g16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates oi2n2c16.png" do
    fixture = File.join(fixtures_dir, "oi2n2c16.png")
    expected = File.join(expected_dir, "oi2n2c16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates oi4n0g16.png" do
    fixture = File.join(fixtures_dir, "oi4n0g16.png")
    expected = File.join(expected_dir, "oi4n0g16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates oi4n2c16.png" do
    fixture = File.join(fixtures_dir, "oi4n2c16.png")
    expected = File.join(expected_dir, "oi4n2c16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates oi9n0g16.png" do
    fixture = File.join(fixtures_dir, "oi9n0g16.png")
    expected = File.join(expected_dir, "oi9n0g16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates oi9n2c16.png" do
    fixture = File.join(fixtures_dir, "oi9n2c16.png")
    expected = File.join(expected_dir, "oi9n2c16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
