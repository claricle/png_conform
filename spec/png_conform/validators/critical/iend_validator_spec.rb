# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/critical/iend_validator"

RSpec.describe PngConform::Validators::Critical::IendValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "IEND", abs_offset: 100)
  end

  describe "#validate" do
    context "with valid IEND chunk" do
      it "validates empty IEND chunk after IHDR and IDAT" do
        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.record_chunk("IHDR")
        context.record_chunk("IDAT")

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be true
        expect(context.has_errors?).to be false
      end

      it "stores IEND flag in context" do
        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.record_chunk("IHDR")
        context.record_chunk("IDAT")

        validator = described_class.new(chunk, context)
        validator.validate

        expect(context.retrieve(:has_iend)).to be true
        expect(context.seen?("IEND")).to be true
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: false)

        context.record_chunk("IHDR")
        context.record_chunk("IDAT")

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("CRC error")
      end
    end

    context "with non-empty IEND" do
      it "rejects IEND chunk with data" do
        data = [0x00, 0x01, 0x02].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.record_chunk("IHDR")
        context.record_chunk("IDAT")

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("invalid IEND chunk length")
        expect(context.all_errors.first[:message]).to include("should be 0")
      end
    end

    context "with invalid positioning" do
      it "rejects IEND before IHDR" do
        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        # No IHDR in context
        context.record_chunk("IDAT")

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("IEND chunk before IHDR")
      end

      it "rejects IEND before IDAT" do
        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.record_chunk("IHDR")
        # No IDAT in context

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("IEND chunk before IDAT")
      end

      it "rejects IEND with neither IHDR nor IDAT" do
        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        # Empty context

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        # Should have two errors: before IHDR and before IDAT
        expect(context.all_errors.length).to eq(2)
      end
    end
  end
end
