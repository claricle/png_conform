# frozen_string_literal: true

require "spec_helper"
require_relative "helpers/semantic_validator"

RSpec.describe "PngSuite Transparency Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) do
    File.expand_path("../fixtures/pngsuite/transparency", __dir__)
  end
  let(:expected_dir) do
    File.expand_path("../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  describe "Simple transparency" do
    it "validates tp0n0g08.png" do
      fixture = File.join(fixtures_dir, "simple", "tp0n0g08.png")
      expected = File.join(expected_dir, "tp0n0g08.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end

    it "validates tp0n2c08.png" do
      fixture = File.join(fixtures_dir, "simple", "tp0n2c08.png")
      expected = File.join(expected_dir, "tp0n2c08.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end

    it "validates tp0n3p08.png" do
      fixture = File.join(fixtures_dir, "simple", "tp0n3p08.png")
      expected = File.join(expected_dir, "tp0n3p08.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end

    it "validates tp1n3p08.png" do
      fixture = File.join(fixtures_dir, "simple", "tp1n3p08.png")
      expected = File.join(expected_dir, "tp1n3p08.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end
  end

  describe "Transparency with background" do
    it "validates tbbn0g04.png" do
      fixture = File.join(fixtures_dir, "with_background", "tbbn0g04.png")
      expected = File.join(expected_dir, "tbbn0g04.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end

    it "validates tbbn2c16.png" do
      fixture = File.join(fixtures_dir, "with_background", "tbbn2c16.png")
      expected = File.join(expected_dir, "tbbn2c16.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end

    it "validates tbbn3p08.png" do
      fixture = File.join(fixtures_dir, "with_background", "tbbn3p08.png")
      expected = File.join(expected_dir, "tbbn3p08.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end

    it "validates tbgn2c16.png" do
      fixture = File.join(fixtures_dir, "with_background", "tbgn2c16.png")
      expected = File.join(expected_dir, "tbgn2c16.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end

    it "validates tbgn3p08.png" do
      fixture = File.join(fixtures_dir, "with_background", "tbgn3p08.png")
      expected = File.join(expected_dir, "tbgn3p08.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end

    it "validates tbrn2c08.png" do
      fixture = File.join(fixtures_dir, "with_background", "tbrn2c08.png")
      expected = File.join(expected_dir, "tbrn2c08.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end

    it "validates tbwn0g16.png" do
      fixture = File.join(fixtures_dir, "with_background", "tbwn0g16.png")
      expected = File.join(expected_dir, "tbwn0g16.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end

    it "validates tbwn3p08.png" do
      fixture = File.join(fixtures_dir, "with_background", "tbwn3p08.png")
      expected = File.join(expected_dir, "tbwn3p08.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end

    it "validates tbyn3p08.png" do
      fixture = File.join(fixtures_dir, "with_background", "tbyn3p08.png")
      expected = File.join(expected_dir, "tbyn3p08.png.out")
      expect(fixture).to pass_semantic_validation(expected)
    end
  end
end
