# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/chunk_registry"

RSpec.describe PngConform::Validators::ChunkRegistry do
  describe ".validator_for" do
    it "returns validator for IHDR" do
      validator = described_class.validator_for("IHDR")
      expect(validator).to eq(PngConform::Validators::Critical::IhdrValidator)
    end

    it "returns validator for PLTE" do
      validator = described_class.validator_for("PLTE")
      expect(validator).to eq(PngConform::Validators::Critical::PlteValidator)
    end

    it "returns validator for IDAT" do
      validator = described_class.validator_for("IDAT")
      expect(validator).to eq(PngConform::Validators::Critical::IdatValidator)
    end

    it "returns validator for IEND" do
      validator = described_class.validator_for("IEND")
      expect(validator).to eq(PngConform::Validators::Critical::IendValidator)
    end

    it "returns validator for gAMA" do
      validator = described_class.validator_for("gAMA")
      expect(validator).to eq(PngConform::Validators::Ancillary::GamaValidator)
    end

    it "returns validator for sRGB" do
      validator = described_class.validator_for("sRGB")
      expect(validator).to eq(PngConform::Validators::Ancillary::SrgbValidator)
    end

    it "returns nil for unknown chunk type" do
      validator = described_class.validator_for("UNKN")
      expect(validator).to be_nil
    end
  end

  describe ".validator_exists?" do
    it "returns true for registered chunk types" do
      expect(described_class.validator_exists?("IHDR")).to be true
      expect(described_class.validator_exists?("PLTE")).to be true
      expect(described_class.validator_exists?("gAMA")).to be true
      expect(described_class.validator_exists?("tEXt")).to be true
    end

    it "returns false for unregistered chunk types" do
      expect(described_class.validator_exists?("UNKN")).to be false
      expect(described_class.validator_exists?("TEST")).to be false
    end
  end

  describe ".chunk_types" do
    it "returns all registered chunk types" do
      chunk_types = described_class.chunk_types
      expect(chunk_types).to include("IHDR", "PLTE", "IDAT", "IEND")
      expect(chunk_types).to include("gAMA", "tRNS", "sRGB", "tEXt")
    end

    it "returns at least 24 chunk types" do
      chunk_types = described_class.chunk_types
      expect(chunk_types.length).to be >= 24
    end
  end

  describe ".validators_by_category" do
    it "returns critical validators" do
      validators = described_class.validators_by_category(:critical)
      expect(validators.keys).to include("IHDR", "PLTE", "IDAT", "IEND")
      expect(validators.length).to eq(4)
    end

    it "returns text chunk validators" do
      validators = described_class.validators_by_category(:text)
      expect(validators.keys).to include("tEXt", "zTXt", "iTXt")
      expect(validators.length).to eq(3)
    end

    it "returns color chunk validators" do
      validators = described_class.validators_by_category(:color)
      expect(validators.keys).to include("gAMA", "cHRM", "sRGB", "iCCP")
    end

    it "returns palette chunk validators" do
      validators = described_class.validators_by_category(:palette)
      expect(validators.keys).to include("tRNS", "hIST", "sPLT")
    end

    it "returns metadata chunk validators" do
      validators = described_class.validators_by_category(:metadata)
      expect(validators.keys).to include("pHYs", "tIME", "oFFs", "pCAL")
    end

    it "returns PNG 3rd edition validators" do
      validators = described_class.validators_by_category(:png3)
      expect(validators.keys).to include("cICP", "mDCv")
    end

    it "returns empty hash for unknown category" do
      validators = described_class.validators_by_category(:unknown)
      expect(validators).to eq({})
    end
  end

  describe ".create_validator" do
    let(:chunk) do
      instance_double(
        PngConform::Models::Chunk,
        type: "gAMA",
        data: "\x00\x00\xB1\x8F".b,
      )
    end

    let(:context) do
      PngConform::Validators::ValidationContext.new
    end

    it "creates validator instance" do
      validator = described_class.create_validator(chunk, context)
      expect(validator).to be_a(PngConform::Validators::Ancillary::GamaValidator)
    end

    it "passes chunk and context to validator" do
      validator = described_class.create_validator(chunk, context)
      expect(validator.instance_variable_get(:@chunk)).to eq(chunk)
      expect(validator.instance_variable_get(:@context)).to eq(context)
    end

    it "returns nil for unknown chunk type" do
      unknown_chunk = instance_double(PngConform::Models::Chunk, type: "UNKN",
                                                                 data: "")
      validator = described_class.create_validator(unknown_chunk, context)
      expect(validator).to be_nil
    end
  end

  describe "validator coverage" do
    it "has validators for all critical chunks" do
      expect(described_class.validator_exists?("IHDR")).to be true
      expect(described_class.validator_exists?("PLTE")).to be true
      expect(described_class.validator_exists?("IDAT")).to be true
      expect(described_class.validator_exists?("IEND")).to be true
    end

    it "has validators for standard ancillary chunks" do
      standard_chunks = %w[
        gAMA cHRM sRGB iCCP sBIT
        bKGD hIST tRNS pHYs sPLT
        tIME tEXt zTXt iTXt
        oFFs pCAL sCAL sTER
      ]

      standard_chunks.each do |chunk_type|
        expect(described_class.validator_exists?(chunk_type)).to be true
      end
    end

    it "has validators for PNG 3rd edition chunks" do
      expect(described_class.validator_exists?("cICP")).to be true
      expect(described_class.validator_exists?("mDCv")).to be true
    end
  end
end
