# frozen_string_literal: true

require "spec_helper"
require_relative "helpers/semantic_validator"

RSpec.describe "PngSuite Size Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) { File.expand_path("../fixtures/pngsuite/sizes", __dir__) }
  let(:expected_dir) do
    File.expand_path("../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  describe "Small dimensions (1x1 to 9x9)" do
    context "non-interlaced" do
      it "validates 1x1 image" do
        fixture = File.join(fixtures_dir, "s01n3p01.png")
        expected = File.join(expected_dir, "s01n3p01.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 2x2 image" do
        fixture = File.join(fixtures_dir, "s02n3p01.png")
        expected = File.join(expected_dir, "s02n3p01.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 3x3 image" do
        fixture = File.join(fixtures_dir, "s03n3p01.png")
        expected = File.join(expected_dir, "s03n3p01.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 4x4 image" do
        fixture = File.join(fixtures_dir, "s04n3p01.png")
        expected = File.join(expected_dir, "s04n3p01.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 5x5 image" do
        fixture = File.join(fixtures_dir, "s05n3p02.png")
        expected = File.join(expected_dir, "s05n3p02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 6x6 image" do
        fixture = File.join(fixtures_dir, "s06n3p02.png")
        expected = File.join(expected_dir, "s06n3p02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 7x7 image" do
        fixture = File.join(fixtures_dir, "s07n3p02.png")
        expected = File.join(expected_dir, "s07n3p02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 8x8 image" do
        fixture = File.join(fixtures_dir, "s08n3p02.png")
        expected = File.join(expected_dir, "s08n3p02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 9x9 image" do
        fixture = File.join(fixtures_dir, "s09n3p02.png")
        expected = File.join(expected_dir, "s09n3p02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end
    end

    context "interlaced" do
      it "validates 1x1 image" do
        fixture = File.join(fixtures_dir, "s01i3p01.png")
        expected = File.join(expected_dir, "s01i3p01.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 2x2 image" do
        fixture = File.join(fixtures_dir, "s02i3p01.png")
        expected = File.join(expected_dir, "s02i3p01.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 3x3 image" do
        fixture = File.join(fixtures_dir, "s03i3p01.png")
        expected = File.join(expected_dir, "s03i3p01.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 4x4 image" do
        fixture = File.join(fixtures_dir, "s04i3p01.png")
        expected = File.join(expected_dir, "s04i3p01.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 5x5 image" do
        fixture = File.join(fixtures_dir, "s05i3p02.png")
        expected = File.join(expected_dir, "s05i3p02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 6x6 image" do
        fixture = File.join(fixtures_dir, "s06i3p02.png")
        expected = File.join(expected_dir, "s06i3p02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 7x7 image" do
        fixture = File.join(fixtures_dir, "s07i3p02.png")
        expected = File.join(expected_dir, "s07i3p02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 8x8 image" do
        fixture = File.join(fixtures_dir, "s08i3p02.png")
        expected = File.join(expected_dir, "s08i3p02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 9x9 image" do
        fixture = File.join(fixtures_dir, "s09i3p02.png")
        expected = File.join(expected_dir, "s09i3p02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end
    end
  end

  describe "Larger dimensions (32x32 to 40x40)" do
    context "non-interlaced" do
      it "validates 32x32 image" do
        fixture = File.join(fixtures_dir, "s32n3p04.png")
        expected = File.join(expected_dir, "s32n3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 33x33 image" do
        fixture = File.join(fixtures_dir, "s33n3p04.png")
        expected = File.join(expected_dir, "s33n3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 34x34 image" do
        fixture = File.join(fixtures_dir, "s34n3p04.png")
        expected = File.join(expected_dir, "s34n3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 35x35 image" do
        fixture = File.join(fixtures_dir, "s35n3p04.png")
        expected = File.join(expected_dir, "s35n3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 36x36 image" do
        fixture = File.join(fixtures_dir, "s36n3p04.png")
        expected = File.join(expected_dir, "s36n3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 37x37 image" do
        fixture = File.join(fixtures_dir, "s37n3p04.png")
        expected = File.join(expected_dir, "s37n3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 38x38 image" do
        fixture = File.join(fixtures_dir, "s38n3p04.png")
        expected = File.join(expected_dir, "s38n3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 39x39 image" do
        fixture = File.join(fixtures_dir, "s39n3p04.png")
        expected = File.join(expected_dir, "s39n3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 40x40 image" do
        fixture = File.join(fixtures_dir, "s40n3p04.png")
        expected = File.join(expected_dir, "s40n3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end
    end

    context "interlaced" do
      it "validates 32x32 image" do
        fixture = File.join(fixtures_dir, "s32i3p04.png")
        expected = File.join(expected_dir, "s32i3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 33x33 image" do
        fixture = File.join(fixtures_dir, "s33i3p04.png")
        expected = File.join(expected_dir, "s33i3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 34x34 image" do
        fixture = File.join(fixtures_dir, "s34i3p04.png")
        expected = File.join(expected_dir, "s34i3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 35x35 image" do
        fixture = File.join(fixtures_dir, "s35i3p04.png")
        expected = File.join(expected_dir, "s35i3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 36x36 image" do
        fixture = File.join(fixtures_dir, "s36i3p04.png")
        expected = File.join(expected_dir, "s36i3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 37x37 image" do
        fixture = File.join(fixtures_dir, "s37i3p04.png")
        expected = File.join(expected_dir, "s37i3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 38x38 image" do
        fixture = File.join(fixtures_dir, "s38i3p04.png")
        expected = File.join(expected_dir, "s38i3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 39x39 image" do
        fixture = File.join(fixtures_dir, "s39i3p04.png")
        expected = File.join(expected_dir, "s39i3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 40x40 image" do
        fixture = File.join(fixtures_dir, "s40i3p04.png")
        expected = File.join(expected_dir, "s40i3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end
    end
  end
end
