# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/mng/seek_validator"

RSpec.describe PngConform::Validators::Mng::SeekValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "SEEK", abs_offset: 600)
  end

  describe "#validate" do
    context "with valid SEEK chunk" do
      it "accepts SEEK with zero length after SAVE" do
        allow(chunk).to receive_messages(chunk_data: "", length: 0,
                                         crc_valid?: true)
        validation_context.store(:mhdr_present, true)
        validation_context.store(:save_present, true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
        expect(validation_context.retrieve(:seek_present)).to be true
      end

      it "accepts SEEK without SAVE (with warning)" do
        allow(chunk).to receive_messages(chunk_data: "", length: 0,
                                         crc_valid?: true)
        validation_context.store(:mhdr_present, true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
        expect(validation_context.retrieve(:seek_present)).to be true
      end
    end

    context "without MHDR" do
      it "rejects SEEK before MHDR" do
        allow(chunk).to receive_messages(chunk_data: "", length: 0,
                                         crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("must appear after MHDR")
      end
    end

    context "with invalid length" do
      it "rejects SEEK with non-zero length" do
        allow(chunk).to receive_messages(chunk_data: "x", length: 1,
                                         crc_valid?: true)
        validation_context.store(:mhdr_present, true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
      end
    end
  end

  describe "#validate (ordering)" do
    before do
      allow(chunk).to receive_messages(chunk_data: "", length: 0,
                                       crc_valid?: true)
      validation_context.store(:mhdr_present, true)
      validation_context.store(:save_present, true)
    end

    it "accepts SEEK before MEND" do
      validator = described_class.new(chunk, validation_context)
      expect(validator.validate).to be true
      expect(validation_context.has_errors?).to be false
    end

    it "rejects SEEK after MEND" do
      validation_context.record_chunk("MEND")

      validator = described_class.new(chunk, validation_context)
      expect(validator.validate).to be false
      expect(validation_context.has_errors?).to be true
      expect(validation_context.all_errors.first[:message]).to include("must appear before MEND")
    end
  end
end
