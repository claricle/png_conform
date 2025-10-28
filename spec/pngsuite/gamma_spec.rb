# frozen_string_literal: true

require "spec_helper"
require_relative "helpers/semantic_validator"

RSpec.describe "PngSuite Gamma Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) { File.expand_path("../fixtures/pngsuite/gamma", __dir__) }
  let(:expected_dir) do
    File.expand_path("../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates g03n0g16.png" do
    fixture = File.join(fixtures_dir, "g03n0g16.png")
    expected = File.join(expected_dir, "g03n0g16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g03n2c08.png" do
    fixture = File.join(fixtures_dir, "g03n2c08.png")
    expected = File.join(expected_dir, "g03n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g03n3p04.png" do
    fixture = File.join(fixtures_dir, "g03n3p04.png")
    expected = File.join(expected_dir, "g03n3p04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g04n0g16.png" do
    fixture = File.join(fixtures_dir, "g04n0g16.png")
    expected = File.join(expected_dir, "g04n0g16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g04n2c08.png" do
    fixture = File.join(fixtures_dir, "g04n2c08.png")
    expected = File.join(expected_dir, "g04n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g04n3p04.png" do
    fixture = File.join(fixtures_dir, "g04n3p04.png")
    expected = File.join(expected_dir, "g04n3p04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g05n0g16.png" do
    fixture = File.join(fixtures_dir, "g05n0g16.png")
    expected = File.join(expected_dir, "g05n0g16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g05n2c08.png" do
    fixture = File.join(fixtures_dir, "g05n2c08.png")
    expected = File.join(expected_dir, "g05n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g05n3p04.png" do
    fixture = File.join(fixtures_dir, "g05n3p04.png")
    expected = File.join(expected_dir, "g05n3p04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g07n0g16.png" do
    fixture = File.join(fixtures_dir, "g07n0g16.png")
    expected = File.join(expected_dir, "g07n0g16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g07n2c08.png" do
    fixture = File.join(fixtures_dir, "g07n2c08.png")
    expected = File.join(expected_dir, "g07n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g07n3p04.png" do
    fixture = File.join(fixtures_dir, "g07n3p04.png")
    expected = File.join(expected_dir, "g07n3p04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g10n0g16.png" do
    fixture = File.join(fixtures_dir, "g10n0g16.png")
    expected = File.join(expected_dir, "g10n0g16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g10n2c08.png" do
    fixture = File.join(fixtures_dir, "g10n2c08.png")
    expected = File.join(expected_dir, "g10n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g10n3p04.png" do
    fixture = File.join(fixtures_dir, "g10n3p04.png")
    expected = File.join(expected_dir, "g10n3p04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g25n0g16.png" do
    fixture = File.join(fixtures_dir, "g25n0g16.png")
    expected = File.join(expected_dir, "g25n0g16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g25n2c08.png" do
    fixture = File.join(fixtures_dir, "g25n2c08.png")
    expected = File.join(expected_dir, "g25n2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates g25n3p04.png" do
    fixture = File.join(fixtures_dir, "g25n3p04.png")
    expected = File.join(expected_dir, "g25n3p04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
