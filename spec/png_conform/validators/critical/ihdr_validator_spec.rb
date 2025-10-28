# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/critical/ihdr_validator"

RSpec.describe PngConform::Validators::Critical::IhdrValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "IHDR", abs_offset: 8)
  end

  describe "#validate" do
    context "with valid IHDR chunk" do
      it "validates 32x32 8-bit grayscale image" do
        data = [
          32, 0, 0, 0,        # width = 32
          32, 0, 0, 0,        # height = 32
          8,                  # bit depth = 8
          0,                  # color type = grayscale
          0,                  # compression = 0
          0,                  # filter = 0
          0 # interlace = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be true
        expect(context.has_errors?).to be false
      end

      it "validates 1920x1080 16-bit truecolor image" do
        data = [
          0x00, 0x00, 0x07, 0x80,  # width = 1920
          0x00, 0x00, 0x04, 0x38,  # height = 1080
          16,                       # bit depth = 16
          2,                        # color type = truecolor
          0,                        # compression = 0
          0,                        # filter = 0
          1                        # interlace = 1 (Adam7)
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be true
        expect(context.has_errors?).to be false
      end

      it "validates 256x256 8-bit indexed-color image" do
        data = [
          0x00, 0x00, 0x01, 0x00,  # width = 256
          0x00, 0x00, 0x01, 0x00,  # height = 256
          8,                        # bit depth = 8
          3,                        # color type = indexed-color
          0,                        # compression = 0
          0,                        # filter = 0
          0 # interlace = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be true
        expect(context.has_errors?).to be false
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        data = [32, 0, 0, 0, 32, 0, 0, 0, 8, 0, 0, 0, 0].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: false)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("CRC error")
      end
    end

    context "with invalid length" do
      it "rejects chunk with wrong length" do
        data = [32, 0, 0, 0, 32, 0, 0, 0, 8, 0, 0, 0].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("invalid IHDR length")
      end
    end

    context "with invalid dimensions" do
      it "rejects zero width" do
        data = [
          0, 0, 0, 0,         # width = 0 (invalid)
          32, 0, 0, 0,        # height = 32
          8, 0, 0, 0, 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("invalid image width (0)")
      end

      it "rejects zero height" do
        data = [
          32, 0, 0, 0,        # width = 32
          0, 0, 0, 0,         # height = 0 (invalid)
          8, 0, 0, 0, 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("invalid image height (0)")
      end
    end

    context "with invalid color type" do
      it "rejects invalid color type" do
        data = [
          32, 0, 0, 0,        # width = 32
          32, 0, 0, 0,        # height = 32
          8,                  # bit depth = 8
          5,                  # color type = 5 (invalid)
          0, 0, 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("invalid color type")
      end
    end

    context "with invalid bit depth for color type" do
      it "rejects 4-bit truecolor" do
        data = [
          32, 0, 0, 0,        # width = 32
          32, 0, 0, 0,        # height = 32
          4,                  # bit depth = 4 (invalid for truecolor)
          2,                  # color type = truecolor
          0, 0, 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("invalid bit depth")
      end

      it "rejects 16-bit indexed-color" do
        data = [
          32, 0, 0, 0,        # width = 32
          32, 0, 0, 0,        # height = 32
          16,                 # bit depth = 16 (invalid for indexed)
          3,                  # color type = indexed-color
          0, 0, 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("invalid bit depth")
      end
    end

    context "with invalid compression method" do
      it "rejects non-zero compression method" do
        data = [
          32, 0, 0, 0,        # width = 32
          32, 0, 0, 0,        # height = 32
          8,                  # bit depth = 8
          0,                  # color type = grayscale
          1,                  # compression = 1 (invalid)
          0, 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("invalid compression method")
      end
    end

    context "with invalid filter method" do
      it "rejects non-zero filter method" do
        data = [
          32, 0, 0, 0,        # width = 32
          32, 0, 0, 0,        # height = 32
          8,                  # bit depth = 8
          0,                  # color type = grayscale
          0,                  # compression = 0
          1,                  # filter = 1 (invalid)
          0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("invalid filter method")
      end
    end

    context "with invalid interlace method" do
      it "rejects invalid interlace method" do
        data = [
          32, 0, 0, 0,        # width = 32
          32, 0, 0, 0,        # height = 32
          8,                  # bit depth = 8
          0,                  # color type = grayscale
          0,                  # compression = 0
          0,                  # filter = 0
          2 # interlace = 2 (invalid)
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        expect(validator.validate).to be false
        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to include("invalid interlace method")
      end
    end

    context "context storage" do
      it "stores IHDR information in context" do
        data = [
          0, 0, 0, 100,       # width = 100
          0, 0, 0, 200,       # height = 200
          8,                  # bit depth = 8
          2,                  # color type = truecolor
          0, 0, 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, context)
        validator.validate

        expect(context.retrieve(:width)).to eq(100)
        expect(context.retrieve(:height)).to eq(200)
        expect(context.retrieve(:bit_depth)).to eq(8)
        expect(context.retrieve(:color_type)).to eq(2)
        expect(context.retrieve(:color_type_name)).to eq("truecolor")
      end
    end
  end
end
