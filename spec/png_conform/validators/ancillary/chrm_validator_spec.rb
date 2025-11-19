# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/ancillary/chrm_validator"

RSpec.describe PngConform::Validators::Ancillary::ChrmValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  before do
    context.width = 100
    context.height = 100
    context.color_type = 2
    context.bit_depth = 8
  end

  describe "#validate" do
    context "with valid CHRM chunk" do
      it "accepts valid data" do
        chunk = create_chunk("chrm",
                             [31_270, 32_900, 64_000, 33_000, 30_000, 60_000,
                              15_000, 6000].pack("N*"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end
    end

    context "with invalid chunk data" do
      it "rejects invalid data format" do
        chunk = create_chunk("chrm", [100].pack("N"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
      end
    end

    context "chunk ordering" do
      it "must appear before IDAT" do
        context.record_chunk("IDAT")
        chunk = create_chunk("chrm",
                             [31_270, 32_900, 64_000, 33_000, 30_000, 60_000,
                              15_000, 6000].pack("N*"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/IDAT/i)
      end
    end

    context "multiple CHRM chunks" do
      before do
        context.record_chunk("cHRM")
      end

      it "rejects multiple CHRM chunks" do
        chunk = create_chunk("chrm",
                             [31_270, 32_900, 64_000, 33_000, 30_000, 60_000,
                              15_000, 6000].pack("N*"))
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
