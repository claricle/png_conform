# frozen_string_literal: true

require "spec_helper"
require_relative "../helpers/semantic_validator"

RSpec.describe "PngSuite Chromaticity (cHRM) Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../../fixtures/pngsuite/ancillary/chromaticity", __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  it "validates ccwn2c08.png" do
    fixture = File.join(fixtures_dir, "ccwn2c08.png")
    expected = File.join(expected_dir, "ccwn2c08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end

  it "validates ccwn3p08.png" do
    fixture = File.join(fixtures_dir, "ccwn3p08.png")
    expected = File.join(expected_dir, "ccwn3p08.png.out")
    expect(fixture).to pass_semantic_validation(expected)
  end
end
