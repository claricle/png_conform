# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/mng/save_validator"

RSpec.describe PngConform::Validators::Mng::SaveValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "SAVE", abs_offset: 500)
  end

  describe "#validate" do
    context "with valid SAVE chunk" do
      it "accepts SAVE with zero length" do
        allow(chunk).to receive_messages(chunk_data: "", crc_valid?: true)
        validation_context.store(:mhdr_present, true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
        expect(validation_context.retrieve(:save_present)).to be true
      end
    end

    context "without MHDR" do
      it "rejects SAVE before MHDR" do
        allow(chunk).to receive_messages(chunk_data: "", crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("must appear after MHDR")
      end
    end

    context "with invalid length" do
      it "rejects SAVE with non-zero length" do
        allow(chunk).to receive_messages(chunk_data: "x", crc_valid?: true)
        validation_context.store(:mhdr_present, true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
      end
    end
  end

  describe "#validate (ordering)" do
    it "accepts SAVE before MEND" do
      allow(chunk).to receive_messages(chunk_data: "", crc_valid?: true)
      validation_context.store(:mhdr_present, true)

      validator = described_class.new(chunk, validation_context)
      expect(validator.validate).to be true
      expect(validation_context.has_errors?).to be false
    end

    it "rejects SAVE after MEND" do
      allow(chunk).to receive_messages(chunk_data: "", crc_valid?: true)
      validation_context.store(:mhdr_present, true)
      validation_context.record_chunk("MEND")

      validator = described_class.new(chunk, validation_context)
      expect(validator.validate).to be false
      expect(validation_context.has_errors?).to be true
      expect(validation_context.all_errors.first[:message]).to include("must appear before MEND")
    end
  end
end
