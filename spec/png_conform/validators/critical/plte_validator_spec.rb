# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/critical/plte_validator"

RSpec.describe PngConform::Validators::Critical::PlteValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "PLTE", abs_offset: 33)
  end

  describe "#validate" do
    context "with valid PLTE chunk" do
      it "validates palette with 256 entries" do
        data = ([255, 0, 0] * 256).pack("C*") # 256 red entries
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        # Set up indexed-color image
        context.store(:color_type, 3)
        context.store(:bit_depth, 8)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be true
        expect(context.has_errors?).to be false
      end

      it "validates palette with 16 entries for 4-bit indexed" do
        data = ([0, 0, 0] * 16).pack("C*") # 16 black entries
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.store(:color_type, 3)
        context.store(:bit_depth, 4)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be true
        expect(context.has_errors?).to be false
      end

      it "validates suggested palette for truecolor" do
        data = ([128, 128, 128] * 10).pack("C*") # 10 gray entries
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.store(:color_type, 2) # Truecolor
        context.store(:bit_depth, 8)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be true
        expect(context.has_errors?).to be false
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        data = ([255, 0, 0] * 10).pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: false)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("CRC error")
      end
    end

    context "with invalid length" do
      it "rejects length not divisible by 3" do
        data = [255, 0, 0, 128].pack("C*") # 4 bytes, not divisible by 3
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("must be divisible by 3")
      end

      it "rejects empty PLTE chunk" do
        data = "".b
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("no entries")
      end

      it "rejects PLTE with more than 256 entries" do
        data = ([255, 0, 0] * 257).pack("C*") # 257 entries
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("maximum is 256")
      end
    end

    context "with invalid color type" do
      it "rejects PLTE for grayscale image" do
        data = ([128, 128, 128] * 10).pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.store(:color_type, 0)  # Grayscale
        context.store(:bit_depth, 8)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("not allowed for grayscale")
      end

      it "rejects PLTE for grayscale+alpha image" do
        data = ([128, 128, 128] * 10).pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.store(:color_type, 4)  # Grayscale + alpha
        context.store(:bit_depth, 8)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("not allowed for grayscale")
      end
    end

    context "with bit depth incompatibility" do
      it "rejects 256 entries for 1-bit indexed image" do
        data = ([255, 0, 0] * 256).pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.store(:color_type, 3)  # Indexed-color
        context.store(:bit_depth, 1)   # Only allows 2 colors

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("allows maximum of 2")
      end

      it "rejects 17 entries for 4-bit indexed image" do
        data = ([255, 0, 0] * 17).pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.store(:color_type, 3)  # Indexed-color
        context.store(:bit_depth, 4)   # Only allows 16 colors

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("allows maximum of 16")
      end
    end

    context "context storage" do
      it "stores palette information in context" do
        data = ([128, 128, 128] * 32).pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        context.store(:color_type, 3)
        context.store(:bit_depth, 8)

        validator = described_class.new(chunk, context)
        validator.validate

        expect(context.retrieve(:palette_entries)).to eq(32)
        expect(context.retrieve(:has_palette)).to be true
      end
    end
  end
end
