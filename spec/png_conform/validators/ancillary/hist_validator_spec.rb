# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Validators::Ancillary::HistValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  before do
    context.width = 100
    context.height = 100
    context.color_type = 3
    context.bit_depth = 8
  end

  describe "#validate" do
    context "with valid HIST chunk" do
      it "accepts valid data" do
        context.store(:has_palette, true)
        context.store(:palette_entries, 4)
        context.record_chunk("PLTE")
        chunk = create_chunk("hist", [100, 200, 150, 180].pack("n*"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end
    end

    context "with invalid chunk data" do
      it "rejects invalid data format" do
        chunk = create_chunk("hist", [100].pack("C"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
      end
    end

    context "chunk ordering" do
      it "must appear before IDAT" do
        context.store(:has_palette, true)
        context.store(:palette_entries, 4)
        context.record_chunk("PLTE")
        context.record_chunk("IDAT")
        chunk = create_chunk("hist", [100, 200, 150, 180].pack("n*"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/IDAT/i)
      end
    end

    context "multiple HIST chunks" do
      before do
        context.store(:has_palette, true)
        context.store(:palette_entries, 4)
        context.record_chunk("PLTE")
        context.store(:has_histogram, true)
      end

      it "rejects multiple HIST chunks" do
        chunk = create_chunk("hist", [100, 200, 150, 180].pack("n*"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/Multiple.*hIST/i)
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
