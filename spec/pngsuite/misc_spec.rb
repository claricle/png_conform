# frozen_string_literal: true

require "spec_helper"
require_relative "helpers/semantic_validator"

RSpec.describe "PngSuite Miscellaneous Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) { File.expand_path("../fixtures/pngsuite/misc", __dir__) }
  let(:expected_dir) do
    File.expand_path("../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  describe "EXIF metadata" do
    it "validates exif2c08.png" do
      fixture = File.join(fixtures_dir, "exif", "exif2c08.png")
      expected = File.join(expected_dir, "exif2c08.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end
  end

  describe "Time metadata" do
    it "validates tm3n3p02.png" do
      fixture = File.join(fixtures_dir, "time", "tm3n3p02.png")
      expected = File.join(expected_dir, "tm3n3p02.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end
  end
end
