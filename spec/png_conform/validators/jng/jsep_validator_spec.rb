# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/jng/jsep_validator"

RSpec.describe PngConform::Validators::Jng::JsepValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "JSEP", abs_offset: 200)
  end

  describe "#validate" do
    context "with valid JSEP chunk" do
      it "accepts JSEP with 12-bit sample depth" do
        validation_context.store(:jhdr_present, true)
        validation_context.store(:jhdr_image_sample_depth, 12)
        validation_context.store(:jdat_count, 1)

        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "marks JSEP as present in context" do
        validation_context.store(:jhdr_present, true)
        validation_context.store(:jhdr_image_sample_depth, 12)
        validation_context.store(:jdat_count, 1)

        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        validator.validate

        expect(validation_context.retrieve(:jsep_present)).to be true
      end
    end

    context "without JHDR" do
      it "rejects JSEP before JHDR" do
        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("must appear after JHDR")
      end
    end

    context "with invalid length" do
      it "rejects JSEP with non-zero length" do
        validation_context.store(:jhdr_present, true)
        validation_context.store(:jhdr_image_sample_depth, 12)

        data = "\x00".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
      end
    end

    context "with invalid sample depth" do
      it "rejects JSEP with 8-bit sample depth" do
        validation_context.store(:jhdr_present, true)
        validation_context.store(:jhdr_image_sample_depth, 8)

        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("12-bit")
      end
    end

    context "ordering" do
      it "accepts JSEP before IEND" do
        validation_context.store(:jhdr_present, true)
        validation_context.store(:jhdr_image_sample_depth, 12)
        validation_context.store(:jdat_count, 1)

        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
      end

      it "rejects JSEP after IEND" do
        validation_context.store(:jhdr_present, true)
        validation_context.store(:jhdr_image_sample_depth, 12)
        validation_context.record_chunk("IEND")

        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("must appear before IEND")
      end

      it "warns when JSEP appears before any JDAT" do
        validation_context.store(:jhdr_present, true)
        validation_context.store(:jhdr_image_sample_depth, 12)

        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        validator.validate

        expect(validation_context.has_warnings?).to be true
      end

      it "accepts JSEP after JDAT chunks" do
        validation_context.store(:jhdr_present, true)
        validation_context.store(:jhdr_image_sample_depth, 12)
        validation_context.store(:jdat_count, 2)

        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
      end
    end

    context "complete validation workflow" do
      it "validates JSEP in proper JNG sequence" do
        # Setup: JHDR has been seen
        validation_context.store(:jhdr_present, true)
        validation_context.store(:jhdr_image_sample_depth, 12)

        # Setup: At least one JDAT has been seen
        validation_context.store(:jdat_count, 1)

        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:jsep_present)).to be true
      end
    end
  end
end
