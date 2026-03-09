# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/ancillary/bkgd_validator"

RSpec.describe PngConform::Validators::Ancillary::BkgdValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  before do
    context.width = 100
    context.height = 100
    context.color_type = 2
    context.bit_depth = 8
  end

  describe "#validate" do
    context "with valid BKGD chunk" do
      it "accepts valid data" do
        # For color type 2 (RGB), bKGD requires 6 bytes (2 bytes each for R, G, B)
        chunk = create_chunk("bKGD", [128, 128, 128].pack("n3"))
        described_class.new(chunk, context).validate

        if context.has_errors?

          context.all_errors.each { |e| }
        end

        expect(context.has_errors?).to be false
      end
    end

    context "with invalid chunk data" do
      it "rejects invalid data format" do
        chunk = create_chunk("bkgd", "")
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
      end
    end

    context "chunk ordering" do
      it "must appear before IDAT" do
        context.record_chunk("IDAT")
        chunk = create_chunk("bkgd", [128, 128, 128].pack("n3"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/IDAT/i)
      end
    end

    context "multiple BKGD chunks" do
      before do
        context.record_chunk("bKGD")
      end

      it "rejects multiple BKGD chunks" do
        chunk = create_chunk("bkgd", [128, 128, 128].pack("n3"))
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
