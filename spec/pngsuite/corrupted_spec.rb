# frozen_string_literal: true

require "spec_helper"
require_relative "helpers/semantic_validator"

RSpec.describe "PngSuite Corrupted File Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../fixtures/pngsuite/corrupted", __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates xc1n0g08.png" do
    fixture = File.join(fixtures_dir, "xc1n0g08.png")
    expected = File.join(expected_dir, "xc1n0g08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates xc9n2c08.png" do
    fixture = File.join(fixtures_dir, "xc9n2c08.png")
    expected = File.join(expected_dir, "xc9n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates xcrn0g04.png" do
    fixture = File.join(fixtures_dir, "xcrn0g04.png")
    expected = File.join(expected_dir, "xcrn0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates xcsn0g01.png" do
    fixture = File.join(fixtures_dir, "xcsn0g01.png")
    expected = File.join(expected_dir, "xcsn0g01.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates xd0n2c08.png" do
    fixture = File.join(fixtures_dir, "xd0n2c08.png")
    expected = File.join(expected_dir, "xd0n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates xd3n2c08.png" do
    fixture = File.join(fixtures_dir, "xd3n2c08.png")
    expected = File.join(expected_dir, "xd3n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates xd9n2c08.png" do
    fixture = File.join(fixtures_dir, "xd9n2c08.png")
    expected = File.join(expected_dir, "xd9n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates xdtn0g01.png" do
    fixture = File.join(fixtures_dir, "xdtn0g01.png")
    expected = File.join(expected_dir, "xdtn0g01.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates xhdn0g08.png" do
    fixture = File.join(fixtures_dir, "xhdn0g08.png")
    expected = File.join(expected_dir, "xhdn0g08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates xlfn0g04.png" do
    fixture = File.join(fixtures_dir, "xlfn0g04.png")
    expected = File.join(expected_dir, "xlfn0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates xs1n0g01.png" do
    fixture = File.join(fixtures_dir, "xs1n0g01.png")
    expected = File.join(expected_dir, "xs1n0g01.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates xs2n0g01.png" do
    fixture = File.join(fixtures_dir, "xs2n0g01.png")
    expected = File.join(expected_dir, "xs2n0g01.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates xs4n0g01.png" do
    fixture = File.join(fixtures_dir, "xs4n0g01.png")
    expected = File.join(expected_dir, "xs4n0g01.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates xs7n0g01.png" do
    fixture = File.join(fixtures_dir, "xs7n0g01.png")
    expected = File.join(expected_dir, "xs7n0g01.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
