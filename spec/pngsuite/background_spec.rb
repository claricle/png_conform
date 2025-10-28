# frozen_string_literal: true

require "spec_helper"
require_relative "helpers/semantic_validator"

RSpec.describe "PngSuite Background Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../fixtures/pngsuite/background", __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates bgai4a08.png" do
    fixture = File.join(fixtures_dir, "bgai4a08.png")
    expected = File.join(expected_dir, "bgai4a08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates bgai4a16.png" do
    fixture = File.join(fixtures_dir, "bgai4a16.png")
    expected = File.join(expected_dir, "bgai4a16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates bgan6a08.png" do
    fixture = File.join(fixtures_dir, "bgan6a08.png")
    expected = File.join(expected_dir, "bgan6a08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates bgan6a16.png" do
    fixture = File.join(fixtures_dir, "bgan6a16.png")
    expected = File.join(expected_dir, "bgan6a16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates bgbn4a08.png" do
    fixture = File.join(fixtures_dir, "bgbn4a08.png")
    expected = File.join(expected_dir, "bgbn4a08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates bggn4a16.png" do
    fixture = File.join(fixtures_dir, "bggn4a16.png")
    expected = File.join(expected_dir, "bggn4a16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates bgwn6a08.png" do
    fixture = File.join(fixtures_dir, "bgwn6a08.png")
    expected = File.join(expected_dir, "bgwn6a08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates bgyn6a16.png" do
    fixture = File.join(fixtures_dir, "bgyn6a16.png")
    expected = File.join(expected_dir, "bgyn6a16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
