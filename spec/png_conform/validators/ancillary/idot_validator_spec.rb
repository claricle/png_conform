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
        data = [1, 2, 3, 4, 5, 6, 7].pack("V7")
        chunk = create_chunk("iDOT", data)

        result = described_class.new(chunk, context).validate

        expect(result).to be true
        expect(context.has_errors?).to be false
      end

      it "stores IdotData model in context" do
        data = [1, 2, 3, 4, 5, 6, 7].pack("V7")
        chunk = create_chunk("iDOT", data)

        described_class.new(chunk, context).validate

        idot_data = context.retrieve(:idot_data)
        expect(idot_data).to be_a(PngConform::Models::IdotData)
        expect(idot_data.display_scale).to eq(1)
        expect(idot_data.pixel_format).to eq(2)
        expect(idot_data.color_space).to eq(3)
        expect(idot_data.backing_scale_factor).to eq(4)
        expect(idot_data.flags).to eq(5)
        expect(idot_data.reserved1).to eq(6)
        expect(idot_data.reserved2).to eq(7)
      end

      it "adds info message with decoded data" do
        data = [1, 2, 3, 4, 5, 6, 7].pack("V7")
        chunk = create_chunk("iDOT", data)

        described_class.new(chunk, context).validate

        info_messages = context.all_info
        expect(info_messages).not_to be_empty
        expect(info_messages.first[:message]).to include("iDOT")
        expect(info_messages.first[:message]).to include("Apple display optimization")
      end
    end

    context "with invalid chunk length" do
      it "rejects data shorter than 28 bytes" do
        data = [1].pack("V")
        chunk = create_chunk("iDOT", data)

        result = described_class.new(chunk, context).validate

        expect(result).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/invalid iDOT length/i)
      end

      it "rejects data longer than 28 bytes" do
        data = [1, 2, 3, 4, 5, 6, 7, 8].pack("V8")
        chunk = create_chunk("iDOT", data)

        result = described_class.new(chunk, context).validate

        expect(result).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/invalid iDOT length/i)
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with invalid CRC" do
        data = [1, 2, 3, 4, 5, 6, 7].pack("V7")
        chunk = create_chunk("iDOT", data, crc_valid: false)

        result = described_class.new(chunk, context).validate

        expect(result).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/CRC error/i)
      end
    end

    context "chunk ordering" do
      it "must appear before IDAT" do
        context.record_chunk("IDAT")
        data = [1, 2, 3, 4, 5, 6, 7].pack("V7")
        chunk = create_chunk("iDOT", data)

        result = described_class.new(chunk, context).validate

        expect(result).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/iDOT chunk after IDAT/i)
      end

      it "accepts iDOT before IDAT" do
        data = [1, 2, 3, 4, 5, 6, 7].pack("V7")
        chunk = create_chunk("iDOT", data)

        described_class.new(chunk, context).validate
        context.record_chunk("IDAT")

        expect(context.has_errors?).to be false
      end
    end

    context "chunk uniqueness" do
      it "rejects duplicate iDOT chunks" do
        # First iDOT chunk
        context.record_chunk("iDOT")

        # Second iDOT chunk
        data = [1, 2, 3, 4, 5, 6, 7].pack("V7")
        chunk = create_chunk("iDOT", data)

        result = described_class.new(chunk, context).validate

        expect(result).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/duplicate iDOT chunk/i)
      end

      it "accepts single iDOT chunk" do
        data = [1, 2, 3, 4, 5, 6, 7].pack("V7")
        chunk = create_chunk("iDOT", data)

        result = described_class.new(chunk, context).validate

        expect(result).to be true
        expect(context.has_errors?).to be false
      end
    end
  end

  def create_chunk(type, data, crc_valid: true)
    PngConform::Models::ChunkInfo.new(
      type: type,
      length: data.bytesize,
      data: data,
      crc: 0,
      offset: 0,
      crc_valid: crc_valid,
    )
  end
end
