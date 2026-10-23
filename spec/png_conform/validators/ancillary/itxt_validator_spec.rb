# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/ancillary/itxt_validator"

RSpec.describe PngConform::Validators::Ancillary::ItxtValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  before do
    context.width = 100
    context.height = 100
    context.color_type = 2
    context.bit_depth = 8
  end

  describe "#validate" do
    context "with valid ITXT chunk" do
      it "accepts valid data" do
        chunk = create_chunk("itxt", "Author\0\0\0\0\0John Doe")
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end
    end

    context "with invalid chunk data" do
      it "rejects invalid data format" do
        chunk = create_chunk("itxt", "Invalid")
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
      end
    end

    context "with an undecompressible payload" do
      it "reports png.iTXt.decompress with its citation and location" do
        chunk = create_chunk("iTXt", "Author\0\1\0\0\0garbage")
        described_class.new(chunk, context).validate

        expect(context.all_errors.first).to have_attributes(
          requirement_id: "png.iTXt.decompress", severity: "error", error_type: "encoding",
          chunk_type: "iTXt", chunk_offset: 0,
          citation_label: a_string_including("ISO/IEC 15948")
        )
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
