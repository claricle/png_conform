# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Validators::Ancillary::MdcvValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  before do
    context.width = 100
    context.height = 100
    context.color_type = 2
    context.bit_depth = 8
  end

  describe "#validate" do
    context "with valid MDCV chunk" do
      it "accepts valid data" do
        chunk = create_chunk("mdcv",
                             [13_250, 34_500, 7500, 3000, 34_000, 16_000, 15_635, 16_450, 10_000_000,
                              1].pack("n8N2"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end
    end

    context "with invalid chunk data" do
      it "rejects invalid data format" do
        chunk = create_chunk("mdcv", [100].pack("n"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
      end
    end

    context "chunk ordering" do
      it "must appear before IDAT" do
        context.record_chunk("IDAT")
        chunk = create_chunk("mdcv",
                             [13_250, 34_500, 7500, 3000, 34_000, 16_000, 15_635, 16_450, 10_000_000,
                              1].pack("n8N2"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/IDAT/i)
      end
    end

    context "multiple MDCV chunks\x00\x00\x00\x00" do
      before do
        context.record_chunk("mDCV")
      end

      it "rejects multiple MDCV chunks" do
        chunk = create_chunk("mdcv",
                             [13_250, 34_500, 7500, 3000, 34_000, 16_000, 15_635, 16_450, 10_000_000,
                              1].pack("n8N2"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/duplicate.*mDCV/i)
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
