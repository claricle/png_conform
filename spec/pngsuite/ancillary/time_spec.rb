# frozen_string_literal: true

require "spec_helper"
require_relative "../helpers/semantic_validator"

RSpec.describe "PngSuite Time (tIME) Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../../fixtures/pngsuite/ancillary/time", __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates cm0n0g04.png" do
    fixture = File.join(fixtures_dir, "cm0n0g04.png")
    expected = File.join(expected_dir, "cm0n0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates cm7n0g04.png" do
    fixture = File.join(fixtures_dir, "cm7n0g04.png")
    expected = File.join(expected_dir, "cm7n0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates cm9n0g04.png" do
    fixture = File.join(fixtures_dir, "cm9n0g04.png")
    expected = File.join(expected_dir, "cm9n0g04.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
