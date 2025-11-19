# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/ancillary/text_validator"

RSpec.describe PngConform::Validators::Ancillary::TextValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  before do
    context.width = 100
    context.height = 100
    context.color_type = 2
    context.bit_depth = 8
  end

  describe "#validate" do
    context "with valid TEXT chunk" do
      it "accepts valid data" do
        chunk = create_chunk("text", "Author\0John Doe")
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end
    end

    context "with invalid chunk data" do
      it "rejects invalid data format" do
        chunk = create_chunk("text", "NoNull")
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
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
