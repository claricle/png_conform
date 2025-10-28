# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Validators::Ancillary::SrgbValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  before do
    context.width = 100
    context.height = 100
    context.color_type = 2
    context.bit_depth = 8
  end

  describe "#validate" do
    context "with valid SRGB chunk" do
      it "accepts valid data" do
        chunk = create_chunk("srgb", [0].pack("C"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end
    end

    context "with invalid chunk data" do
      it "rejects invalid data format" do
        chunk = create_chunk("srgb", [4].pack("C"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
      end
    end

    context "chunk ordering" do
      it "must appear before IDAT" do
        context.record_chunk("IDAT")
        chunk = create_chunk("srgb", [0].pack("C"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/IDAT/i)
      end
    end

    context "multiple SRGB chunks" do
      before do
        context.record_chunk("sRGB")
      end

      it "rejects multiple SRGB chunks" do
        chunk = create_chunk("srgb", [0].pack("C"))
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
