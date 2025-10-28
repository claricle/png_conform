# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/jng/jdat_validator"

RSpec.describe PngConform::Validators::Jng::JdatValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "JDAT", abs_offset: 100)
  end

  describe "#validate" do
    context "with valid JDAT chunk" do
      it "accepts JDAT with JPEG data" do
        validation_context.store(:jhdr_present, true)
        data = "\xFF\xD8\xFF\xE0\x00\x10JFIF".b # JPEG header
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "accepts minimum 1-byte JDAT" do
        validation_context.store(:jhdr_present, true)
        data = "\xFF".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "tracks JDAT count" do
        validation_context.store(:jhdr_present, true)
        data = "\xFF\xD8".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        validator.validate

        expect(validation_context.retrieve(:jdat_count)).to eq(1)
      end

      it "tracks total JDAT data length" do
        validation_context.store(:jhdr_present, true)
        data = "\xFF\xD8\xFF\xE0\x00\x10JFIF".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        validator.validate

        expect(validation_context.retrieve(:jdat_data_length)).to eq(data.length)
      end
    end

    context "without JHDR" do
      it "rejects JDAT before JHDR" do
        data = "\xFF\xD8".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("must appear after JHDR")
      end
    end

    context "with invalid length" do
      it "rejects empty JDAT" do
        validation_context.store(:jhdr_present, true)
        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("too short")
      end
    end

    context "ordering" do
      it "accepts JDAT before IEND" do
        validation_context.store(:jhdr_present, true)
        data = "\xFF\xD8".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "rejects JDAT after IEND" do
        validation_context.store(:jhdr_present, true)
        validation_context.record_chunk("IEND")

        data = "\xFF\xD8".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("must appear before IEND")
      end
    end

    context "multiple JDAT chunks" do
      it "allows multiple JDAT chunks" do
        validation_context.store(:jhdr_present, true)
        data1 = "\xFF\xD8".b
        data2 = "\xFF\xE0".b

        allow(chunk).to receive(:chunk_data).and_return(data1)
        allow(chunk).to receive(:crc_valid?).and_return(true)

        validator1 = described_class.new(chunk, validation_context)
        expect(validator1.validate).to be true

        allow(chunk).to receive(:chunk_data).and_return(data2)
        validator2 = described_class.new(chunk, validation_context)
        expect(validator2.validate).to be true

        expect(validation_context.retrieve(:jdat_count)).to eq(2)
      end

      it "accumulates total data length from multiple chunks" do
        validation_context.store(:jhdr_present, true)
        data1 = "\xFF\xD8".b # 2 bytes
        data2 = "\xFF\xE0\x00".b # 3 bytes

        allow(chunk).to receive(:chunk_data).and_return(data1)
        allow(chunk).to receive(:crc_valid?).and_return(true)

        validator1 = described_class.new(chunk, validation_context)
        validator1.validate

        allow(chunk).to receive(:chunk_data).and_return(data2)
        validator2 = described_class.new(chunk, validation_context)
        validator2.validate

        expect(validation_context.retrieve(:jdat_data_length)).to eq(5)
      end
    end
  end
end
