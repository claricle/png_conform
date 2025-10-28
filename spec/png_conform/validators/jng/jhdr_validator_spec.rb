# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/jng/jhdr_validator"

RSpec.describe PngConform::Validators::Jng::JhdrValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "JHDR", abs_offset: 8)
  end

  describe "#validate" do
    context "with valid JHDR chunk" do
      it "validates 640x480 8-bit grayscale JPEG" do
        data = [
          0x00, 0x00, 0x02, 0x80,  # width = 640
          0x00, 0x00, 0x01, 0xE0,  # height = 480
          8,                        # color_type = 8 (grayscale)
          8,                        # image_sample_depth = 8
          8,                        # image_compression = 8 (JPEG)
          0,                        # interlace = 0
          0,                        # alpha_sample_depth = 0
          0,                        # alpha_compression = 0
          0,                        # alpha_filter = 0
          0                        # alpha_interlace = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "validates 800x600 12-bit truecolor JPEG" do
        data = [
          0x00, 0x00, 0x03, 0x20,  # width = 800
          0x00, 0x00, 0x02, 0x58,  # height = 600
          12,                       # color_type = 12 (truecolor)
          12,                       # image_sample_depth = 12
          8,                        # image_compression = 8
          0,                        # interlace = 0
          0,                        # alpha_sample_depth = 0
          0,                        # alpha_compression = 0
          0,                        # alpha_filter = 0
          0                        # alpha_interlace = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "validates color type 10 (grayscale+alpha)" do
        data = [
          0x00, 0x00, 0x01, 0x00,  # width = 256
          0x00, 0x00, 0x01, 0x00,  # height = 256
          10,                       # color_type = 10
          8,                        # image_sample_depth = 8
          8,                        # image_compression = 8
          0,                        # interlace = 0
          8,                        # alpha_sample_depth = 8
          0,                        # alpha_compression = 0
          0,                        # alpha_filter = 0
          0                        # alpha_interlace = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "validates color type 14 (truecolor+alpha)" do
        data = [
          0x00, 0x00, 0x01, 0x00,  # width = 256
          0x00, 0x00, 0x01, 0x00,  # height = 256
          14,                       # color_type = 14
          8,                        # image_sample_depth = 8
          8,                        # image_compression = 8
          0,                        # interlace = 0
          8,                        # alpha_sample_depth = 8
          0,                        # alpha_compression = 0
          0,                        # alpha_filter = 0
          0                        # alpha_interlace = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        data = [0, 0, 1, 0, 0, 0, 1, 0, 8, 8, 8, 0, 0, 0, 0, 0].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: false)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("CRC error")
      end
    end

    context "with invalid length" do
      it "rejects chunk with wrong length" do
        data = [0, 0, 1, 0, 0, 0, 1, 0, 8, 8, 8, 0, 0, 0, 0].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("invalid JHDR length")
      end
    end

    context "with invalid dimensions" do
      it "rejects zero width" do
        data = [
          0, 0, 0, 0,              # width = 0 (invalid)
          0, 0, 1, 0,              # height = 256
          8,                        # color_type = 8
          8,                        # image_sample_depth = 8
          8,                        # compression = 8
          0,                        # interlace = 0
          0,                        # alpha_sample_depth = 0
          0,                        # alpha_compression = 0
          0,                        # alpha_filter = 0
          0                        # alpha_interlace = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("invalid image width")
      end

      it "rejects zero height" do
        data = [
          0, 0, 1, 0,              # width = 256
          0, 0, 0, 0,              # height = 0 (invalid)
          8,                        # color_type = 8
          8,                        # image_sample_depth = 8
          8,                        # compression = 8
          0,                        # interlace = 0
          0,                        # alpha_sample_depth = 0
          0,                        # alpha_compression = 0
          0,                        # alpha_filter = 0
          0                        # alpha_interlace = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("invalid image height")
      end
    end

    context "with invalid color type" do
      it "rejects invalid color type" do
        data = [
          0, 0, 1, 0,              # width = 256
          0, 0, 1, 0,              # height = 256
          5,                        # color_type = 5 (invalid)
          8,                        # image_sample_depth = 8
          8,                        # compression = 8
          0,                        # interlace = 0
          0,                        # alpha_sample_depth = 0
          0,                        # alpha_compression = 0
          0,                        # alpha_filter = 0
          0                        # alpha_interlace = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("color type")
      end
    end

    context "with invalid sample depth" do
      it "rejects 16-bit sample depth" do
        data = [
          0, 0, 1, 0,              # width = 256
          0, 0, 1, 0,              # height = 256
          8,                        # color_type = 8
          16,                       # image_sample_depth = 16 (invalid)
          8,                        # compression = 8
          0,                        # interlace = 0
          0,                        # alpha_sample_depth = 0
          0,                        # alpha_compression = 0
          0,                        # alpha_filter = 0
          0                        # alpha_interlace = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("image sample depth")
      end
    end

    context "with invalid compression method" do
      it "rejects non-8 compression method" do
        data = [
          0, 0, 1, 0,              # width = 256
          0, 0, 1, 0,              # height = 256
          8,                        # color_type = 8
          8,                        # image_sample_depth = 8
          0,                        # compression = 0 (invalid)
          0,                        # interlace = 0
          0,                        # alpha_sample_depth = 0
          0,                        # alpha_compression = 0
          0,                        # alpha_filter = 0
          0                        # alpha_interlace = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("image compression method")
      end
    end

    context "with invalid interlace method" do
      it "rejects non-zero interlace method" do
        data = [
          0, 0, 1, 0,              # width = 256
          0, 0, 1, 0,              # height = 256
          8,                        # color_type = 8
          8,                        # image_sample_depth = 8
          8,                        # compression = 8
          1,                        # interlace = 1 (invalid)
          0,                        # alpha_sample_depth = 0
          0,                        # alpha_compression = 0
          0,                        # alpha_filter = 0
          0                        # alpha_interlace = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("interlace method")
      end
    end

    context "ordering validation" do
      it "accepts JHDR as first chunk" do
        data = [0, 0, 1, 0, 0, 0, 1, 0, 8, 8, 8, 0, 0, 0, 0, 0].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "rejects JHDR after other chunks" do
        validation_context.record_chunk("JDAT")

        data = [0, 0, 1, 0, 0, 0, 1, 0, 8, 8, 8, 0, 0, 0, 0, 0].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("must be the first chunk")
      end
    end

    context "context storage" do
      it "stores JHDR information in context" do
        data = [
          0x00, 0x00, 0x01, 0x00,  # width = 256
          0x00, 0x00, 0x02, 0x00,  # height = 512
          12,                       # color_type = 12
          8,                        # image_sample_depth = 8
          8,                        # image_compression = 8
          0,                        # interlace = 0
          0,                        # alpha_sample_depth = 0
          0,                        # alpha_compression = 0
          0,                        # alpha_filter = 0
          0 # alpha_interlace = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        validator.validate

        expect(validation_context.retrieve(:jhdr_width)).to eq(256)
        expect(validation_context.retrieve(:jhdr_height)).to eq(512)
        expect(validation_context.retrieve(:jhdr_color_type)).to eq(12)
        expect(validation_context.retrieve(:jhdr_image_sample_depth)).to eq(8)
      end
    end
  end
end
