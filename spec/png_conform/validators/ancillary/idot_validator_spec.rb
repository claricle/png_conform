# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/ancillary/idot_validator"

RSpec.describe PngConform::Validators::Ancillary::IdotValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  before do
    context.width = 100
    context.height = 100
    context.color_type = 2
    context.bit_depth = 8
  end

  describe "#validate" do
    context "with valid iDOT chunk" do
      it "accepts valid 28-byte data" do
        # Create 7 32-bit little-endian integers (28 bytes total)
        data = [1, 2, 3, 4, 5, 6, 7].pack("V7")
        chunk = create_chunk("idot", data)
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end
    end

    context "with invalid chunk data" do
      it "rejects wrong length data" do
        # Only 4 bytes instead of 28
        chunk = create_chunk("idot", [1].pack("V"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/wrong length/i)
      end

      it "rejects data with too many bytes" do
        # 32 bytes instead of 28
        chunk = create_chunk("idot", [1, 2, 3, 4, 5, 6, 7, 8].pack("V8"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/wrong length/i)
      end
    end

    context "chunk ordering" do
      it "must appear before IDAT" do
        context.record_chunk("IDAT")
        data = [1, 2, 3, 4, 5, 6, 7].pack("V7")
        chunk = create_chunk("idot", data)
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/IDAT/i)
      end
    end

    context "multiple iDOT chunks" do
      before do
        context.store(:has_idot, true)
      end

      it "rejects multiple iDOT chunks" do
        data = [1, 2, 3, 4, 5, 6, 7].pack("V7")
        chunk = create_chunk("idot", data)
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
