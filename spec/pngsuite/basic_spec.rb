# frozen_string_literal: true

require "spec_helper"
require_relative "helpers/semantic_validator"

RSpec.describe "PngSuite Basic Format Tests" do
  include PngSuite::Helpers

  let(:fixtures_dir) { File.expand_path("../fixtures/pngsuite/basic", __dir__) }
  let(:expected_dir) do
    File.expand_path("../fixtures/pngcheck-pngsuite-output", __dir__)
  end

  describe "Non-interlaced basic formats" do
    context "grayscale images" do
      it "validates 1-bit grayscale" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn0g01.png")
        expected = File.join(expected_dir, "basn0g01.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 2-bit grayscale" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn0g02.png")
        expected = File.join(expected_dir, "basn0g02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 4-bit grayscale" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn0g04.png")
        expected = File.join(expected_dir, "basn0g04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 8-bit grayscale" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn0g08.png")
        expected = File.join(expected_dir, "basn0g08.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 16-bit grayscale" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn0g16.png")
        expected = File.join(expected_dir, "basn0g16.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end
    end

    context "truecolor images" do
      it "validates 8-bit RGB" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn2c08.png")
        expected = File.join(expected_dir, "basn2c08.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 16-bit RGB" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn2c16.png")
        expected = File.join(expected_dir, "basn2c16.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end
    end

    context "paletted images" do
      it "validates 1-bit palette" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn3p01.png")
        expected = File.join(expected_dir, "basn3p01.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 2-bit palette" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn3p02.png")
        expected = File.join(expected_dir, "basn3p02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 4-bit palette" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn3p04.png")
        expected = File.join(expected_dir, "basn3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 8-bit palette" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn3p08.png")
        expected = File.join(expected_dir, "basn3p08.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end
    end

    context "images with alpha channel" do
      it "validates 8-bit grayscale with alpha" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn4a08.png")
        expected = File.join(expected_dir, "basn4a08.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 16-bit grayscale with alpha" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn4a16.png")
        expected = File.join(expected_dir, "basn4a16.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 8-bit RGBA" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn6a08.png")
        expected = File.join(expected_dir, "basn6a08.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 16-bit RGBA" do
        fixture = File.join(fixtures_dir, "non_interlaced/basn6a16.png")
        expected = File.join(expected_dir, "basn6a16.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end
    end
  end

  describe "Interlaced basic formats (Adam7)" do
    context "grayscale images" do
      it "validates 1-bit grayscale" do
        fixture = File.join(fixtures_dir, "interlaced/basi0g01.png")
        expected = File.join(expected_dir, "basi0g01.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 2-bit grayscale" do
        fixture = File.join(fixtures_dir, "interlaced/basi0g02.png")
        expected = File.join(expected_dir, "basi0g02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 4-bit grayscale" do
        fixture = File.join(fixtures_dir, "interlaced/basi0g04.png")
        expected = File.join(expected_dir, "basi0g04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 8-bit grayscale" do
        fixture = File.join(fixtures_dir, "interlaced/basi0g08.png")
        expected = File.join(expected_dir, "basi0g08.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 16-bit grayscale" do
        fixture = File.join(fixtures_dir, "interlaced/basi0g16.png")
        expected = File.join(expected_dir, "basi0g16.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end
    end

    context "truecolor images" do
      it "validates 8-bit RGB" do
        fixture = File.join(fixtures_dir, "interlaced/basi2c08.png")
        expected = File.join(expected_dir, "basi2c08.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 16-bit RGB" do
        fixture = File.join(fixtures_dir, "interlaced/basi2c16.png")
        expected = File.join(expected_dir, "basi2c16.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end
    end

    context "paletted images" do
      it "validates 1-bit palette" do
        fixture = File.join(fixtures_dir, "interlaced/basi3p01.png")
        expected = File.join(expected_dir, "basi3p01.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 2-bit palette" do
        fixture = File.join(fixtures_dir, "interlaced/basi3p02.png")
        expected = File.join(expected_dir, "basi3p02.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 4-bit palette" do
        fixture = File.join(fixtures_dir, "interlaced/basi3p04.png")
        expected = File.join(expected_dir, "basi3p04.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 8-bit palette" do
        fixture = File.join(fixtures_dir, "interlaced/basi3p08.png")
        expected = File.join(expected_dir, "basi3p08.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end
    end

    context "images with alpha channel" do
      it "validates 8-bit grayscale with alpha" do
        fixture = File.join(fixtures_dir, "interlaced/basi4a08.png")
        expected = File.join(expected_dir, "basi4a08.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 16-bit grayscale with alpha" do
        fixture = File.join(fixtures_dir, "interlaced/basi4a16.png")
        expected = File.join(expected_dir, "basi4a16.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 8-bit RGBA" do
        fixture = File.join(fixtures_dir, "interlaced/basi6a08.png")
        expected = File.join(expected_dir, "basi6a08.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end

      it "validates 16-bit RGBA" do
        fixture = File.join(fixtures_dir, "interlaced/basi6a16.png")
        expected = File.join(expected_dir, "basi6a16.png.out")
        expect(fixture).to pass_semantic_validation(expected)
      end
    end
  end
end
