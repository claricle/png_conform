# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/mng/mhdr_validator"

RSpec.describe PngConform::Validators::Mng::MhdrValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "MHDR", abs_offset: 8)
  end

  describe "#validate" do
    context "with valid MHDR chunk" do
      it "validates 640x480 MNG with basic parameters" do
        data = [
          0x00, 0x00, 0x02, 0x80,  # frame_width = 640
          0x00, 0x00, 0x01, 0xE0,  # frame_height = 480
          0x00, 0x00, 0x00, 0x1E,  # ticks_per_second = 30
          0x00, 0x00, 0x00, 0x01,  # nominal_layer_count = 1
          0x00, 0x00, 0x00, 0x0A,  # nominal_frame_count = 10
          0x00, 0x00, 0x00, 0x00,  # nominal_play_time = 0
          0x00, 0x00, 0x00, 0x00 # simplicity_profile = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "validates 1920x1080 MNG with animation parameters" do
        data = [
          0x00, 0x00, 0x07, 0x80,  # frame_width = 1920
          0x00, 0x00, 0x04, 0x38,  # frame_height = 1080
          0x00, 0x00, 0x00, 0x3C,  # ticks_per_second = 60
          0x00, 0x00, 0x00, 0x05,  # nominal_layer_count = 5
          0x00, 0x00, 0x00, 0x64,  # nominal_frame_count = 100
          0x00, 0x00, 0x03, 0xE8,  # nominal_play_time = 1000
          0x00, 0x00, 0x00, 0x01 # simplicity_profile = 1
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        data = [0, 0, 1, 0] * 7  # 28 bytes
        allow(chunk).to receive_messages(chunk_data: data.pack("C*"),
                                         crc_valid?: false)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("CRC error")
      end
    end

    context "with invalid length" do
      it "rejects chunk with wrong length" do
        data = [0, 0, 1, 0] * 6  # 24 bytes instead of 28
        allow(chunk).to receive_messages(chunk_data: data.pack("C*"),
                                         crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("invalid MHDR length")
      end
    end

    context "with invalid dimensions" do
      it "rejects zero frame width" do
        data = [
          0, 0, 0, 0,              # frame_width = 0 (invalid)
          0, 0, 1, 0,              # frame_height = 256
          0, 0, 0, 30,             # ticks_per_second = 30
          0, 0, 0, 1,              # nominal_layer_count = 1
          0, 0, 0, 10,             # nominal_frame_count = 10
          0, 0, 0, 0,              # nominal_play_time = 0
          0, 0, 0, 0 # simplicity_profile = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("frame dimensions must be > 0")
      end

      it "rejects zero frame height" do
        data = [
          0, 0, 1, 0,              # frame_width = 256
          0, 0, 0, 0,              # frame_height = 0 (invalid)
          0, 0, 0, 30,             # ticks_per_second = 30
          0, 0, 0, 1,              # nominal_layer_count = 1
          0, 0, 0, 10,             # nominal_frame_count = 10
          0, 0, 0, 0,              # nominal_play_time = 0
          0, 0, 0, 0 # simplicity_profile = 0
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("frame dimensions must be > 0")
      end
    end

    context "ordering validation" do
      it "accepts MHDR as first chunk" do
        data = [0, 0, 1, 0] * 7
        allow(chunk).to receive_messages(chunk_data: data.pack("C*"),
                                         crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "rejects MHDR after other chunks" do
        validation_context.record_chunk("FRAM")

        data = [0, 0, 1, 0] * 7
        allow(chunk).to receive_messages(chunk_data: data.pack("C*"),
                                         crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("must be the first chunk")
      end
    end

    context "context storage" do
      it "stores MHDR information in context" do
        data = [
          0x00, 0x00, 0x03, 0x20,  # frame_width = 800
          0x00, 0x00, 0x02, 0x58,  # frame_height = 600
          0x00, 0x00, 0x00, 0x19,  # ticks_per_second = 25
          0x00, 0x00, 0x00, 0x03,  # nominal_layer_count = 3
          0x00, 0x00, 0x00, 0x32,  # nominal_frame_count = 50
          0x00, 0x00, 0x00, 0xC8,  # nominal_play_time = 200
          0x00, 0x00, 0x00, 0x02 # simplicity_profile = 2
        ].pack("C*")

        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        validator.validate

        expect(validation_context.retrieve(:mhdr_frame_width)).to eq(800)
        expect(validation_context.retrieve(:mhdr_frame_height)).to eq(600)
        expect(validation_context.retrieve(:mhdr_ticks_per_second)).to eq(25)
        expect(validation_context.retrieve(:mhdr_nominal_layer_count)).to eq(3)
        expect(validation_context.retrieve(:mhdr_nominal_frame_count)).to eq(50)
        expect(validation_context.retrieve(:mhdr_nominal_play_time)).to eq(200)
        expect(validation_context.retrieve(:mhdr_simplicity_profile)).to eq(2)
      end
    end
  end
end
