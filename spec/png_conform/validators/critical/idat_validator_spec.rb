# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/critical/idat_validator"

RSpec.describe PngConform::Validators::Critical::IdatValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "IDAT", abs_offset: 45)
  end

  describe "#validate" do
    context "with valid IDAT chunk" do
      it "validates IDAT with compressed data" do
        # Simplified zlib compressed data (just for structure testing)
        data = [0x78, 0x9c, 0x63, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        # Set up context as if IHDR was already seen
        context.record_chunk("IHDR")
        context.store(:color_type, 0)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be true
        expect(context.has_errors?).to be false
      end

      it "validates IDAT after PLTE for indexed-color" do
        data = [0x78, 0x9c, 0x63, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.record_chunk("IHDR")
        context.record_chunk("PLTE")
        context.store(:color_type, 3) # Indexed-color

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be true
        expect(context.has_errors?).to be false
      end

      it "tracks multiple IDAT chunks" do
        data1 = [0x78, 0x9c, 0x63, 0x00].pack("C*")
        data2 = [0x00, 0x00, 0x02, 0x00, 0x01].pack("C*")

        chunk1 = double("chunk1", chunk_type: "IDAT", abs_offset: 45,
                                  chunk_data: data1, crc_valid?: true)
        chunk2 = double("chunk2", chunk_type: "IDAT", abs_offset: 57,
                                  chunk_data: data2, crc_valid?: true)

        context.record_chunk("IHDR")
        context.store(:color_type, 0)

        validator1 = described_class.new(chunk1, context)
        validator1.validate

        validator2 = described_class.new(chunk2, context)
        validator2.validate

        expect(context.chunks_of_type("IDAT").length).to eq(2)
        expect(context.retrieve(:total_idat_size)).to eq(data1.length + data2.length)
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        data = [0x78, 0x9c, 0x63, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: false)

        context.record_chunk("IHDR")

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("CRC error")
      end
    end

    context "with empty IDAT" do
      it "rejects empty IDAT chunk" do
        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.record_chunk("IHDR")

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("IDAT chunk is empty")
      end
    end

    context "with invalid positioning" do
      it "rejects IDAT before IHDR" do
        data = [0x78, 0x9c, 0x63, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        # No IHDR in context

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("IDAT chunk before IHDR")
      end

      it "rejects IDAT before PLTE for indexed-color" do
        data = [0x78, 0x9c, 0x63, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.record_chunk("IHDR")
        context.store(:color_type, 3) # Indexed-color
        # No PLTE in context

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("IDAT chunk before PLTE")
      end
    end

    context "context storage" do
      it "records IDAT chunk in context" do
        data = [0x78, 0x9c, 0x63, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.record_chunk("IHDR")
        context.store(:color_type, 0)

        validator = described_class.new(chunk, context)
        validator.validate

        expect(context.seen?("IDAT")).to be true
        expect(context.chunks_of_type("IDAT").length).to eq(1)
        expect(context.retrieve(:total_idat_size)).to eq(data.length)
      end
    end
  end
end
