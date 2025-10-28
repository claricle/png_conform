# frozen_string_literal: true

require "spec_helper"
require_relative "../helpers/semantic_validator"

RSpec.describe "PngSuite Palette Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../../fixtures/pngsuite/ancillary/palette", __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates pp0n2c16.png" do
    fixture = File.join(fixtures_dir, "pp0n2c16.png")
    expected = File.join(expected_dir, "pp0n2c16.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates pp0n6a08.png" do
    fixture = File.join(fixtures_dir, "pp0n6a08.png")
    expected = File.join(expected_dir, "pp0n6a08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
