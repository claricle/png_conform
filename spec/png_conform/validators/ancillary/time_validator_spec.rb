# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/ancillary/time_validator"

RSpec.describe PngConform::Validators::Ancillary::TimeValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  before do
    context.width = 100
    context.height = 100
    context.color_type = 2
    context.bit_depth = 8
  end

  describe "#validate" do
    context "with valid TIME chunk" do
      it "accepts valid data" do
        chunk = create_chunk("time", [2024, 10, 21, 12, 30, 45].pack("nCCCCC"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end
    end

    context "with invalid chunk data" do
      it "rejects invalid data format" do
        chunk = create_chunk("time", [2024].pack("n"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
      end
    end

    context "multiple TIME chunks" do
      before do
        context.record_chunk("tIME")
      end

      it "rejects multiple TIME chunks" do
        chunk = create_chunk("time", [2024, 10, 21, 12, 30, 45].pack("nCCCCC"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/multiple|duplicate/i)
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
