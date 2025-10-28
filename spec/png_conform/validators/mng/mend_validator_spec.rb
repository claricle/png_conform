# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/mng/mend_validator"

RSpec.describe PngConform::Validators::Mng::MendValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "MEND", abs_offset: 1000)
  end

  describe "#validate" do
    context "with valid MEND chunk" do
      it "validates MEND with zero length" do
        allow(chunk).to receive_messages(chunk_data: "", crc_valid?: true)
        validation_context.record_chunk("MHDR")

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        allow(chunk).to receive_messages(chunk_data: "", crc_valid?: false)
        validation_context.record_chunk("MHDR")

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("CRC error")
      end
    end

    context "with invalid length" do
      it "rejects chunk with non-zero length" do
        allow(chunk).to receive_messages(chunk_data: "x", crc_valid?: true)
        validation_context.record_chunk("MHDR")

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("invalid MEND length")
      end
    end

    context "ordering validation" do
      it "accepts MEND after MHDR" do
        allow(chunk).to receive_messages(chunk_data: "", crc_valid?: true)
        validation_context.record_chunk("MHDR")

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "rejects MEND without MHDR" do
        allow(chunk).to receive_messages(chunk_data: "", crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("requires MHDR chunk")
      end
    end
  end
end
