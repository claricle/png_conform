# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/ancillary/scal_validator"

RSpec.describe PngConform::Validators::Ancillary::ScalValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  before do
    context.width = 100
    context.height = 100
    context.color_type = 2
    context.bit_depth = 8
  end

  describe "#validate" do
    context "with valid SCAL chunk" do
      it "accepts valid data" do
        chunk = create_chunk("scal", "\x01100\x00100\x00")
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end
    end

    context "with invalid chunk data" do
      it "rejects invalid data format" do
        chunk = create_chunk("scal", "Invalid")
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
      end
    end

    context "chunk ordering" do
      it "must appear before IDAT" do
        context.record_chunk("IDAT")
        chunk = create_chunk("scal", "\x01100\x00100\x00")
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/IDAT/i)
      end
    end

    context "multiple SCAL chunks" do
      before do
        context.record_chunk("sCAL")
      end

      it "rejects multiple SCAL chunks" do
        chunk = create_chunk("scal", "\x01100\x00100\x00")
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/duplicate.*sCAL/i)
      end
    end
  end

  def create_chunk(type, data)
    PngConform::Models::ChunkInfo.new(
      type: type,
      length: data.bytesize,
      data: data,
      crc: 0,
      offset: 0,
      crc_valid: true,
    )
  end
end
