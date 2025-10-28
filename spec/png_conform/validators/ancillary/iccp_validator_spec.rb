# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Validators::Ancillary::IccpValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  before do
    context.width = 100
    context.height = 100
    context.color_type = 2
    context.bit_depth = 8
  end

  describe "#validate" do
    context "with valid ICCP chunk" do
      it "accepts valid data" do
        # Create minimal valid ICC profile (128 bytes minimum)
        profile_data = "\x00" * 128 # Start with 128 null bytes
        profile_data[36, 4] = "acsp" # Add signature at offset 36
        chunk = create_chunk("iccp", "sRGB\u0000\u0000#{Zlib::Deflate.deflate(profile_data)}")
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end
    end

    context "with invalid chunk data" do
      it "rejects invalid data format" do
        chunk = create_chunk("iccp", "NoNull")
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
      end
    end

    context "chunk ordering" do
      it "must appear before IDAT" do
        context.record_chunk("IDAT")
        chunk = create_chunk("iccp",
                             "sRGB\u0000\u0000#{Zlib::Deflate.deflate('ICC Profile Data')}")
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/IDAT/i)
      end
    end

    context "multiple ICCP chunks" do
      before do
        context.record_chunk("iCCP")
      end

      it "rejects multiple ICCP chunks" do
        profile_data = "\x00" * 128
        profile_data[36, 4] = "acsp"

        # First iCCP chunk - should succeed
        chunk1 = create_chunk("iCCP", "sRGB\u0000\u0000#{Zlib::Deflate.deflate(profile_data)}")
        validator1 = described_class.new(chunk1, context)
        validator1.validate

        # Second iCCP chunk - should fail
        chunk2 = create_chunk("iCCP", "Adobe RGB\u0000\u0000#{Zlib::Deflate.deflate(profile_data)}")
        validator2 = described_class.new(chunk2, context)
        validator2.validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/multiple.*iCCP/i)
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
