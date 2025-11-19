# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/mng/back_validator"

RSpec.describe PngConform::Validators::Mng::BackValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }
  let(:validator) { described_class.new(chunk, validation_context) }

  before do
    allow(chunk).to receive_messages(crc_valid?: true, chunk_type: "BACK",
                                     abs_offset: 0)
  end

  describe "#validate" do
    context "with valid 6-byte BACK chunk" do
      it "accepts RGB color values" do
        validation_context.store(:mhdr_present, true)
        # Red: 255, Green: 128, Blue: 0
        data = [255, 128, 0].pack("nnn")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be true
        expect(validation_context.errors).to be_empty
        expect(validation_context.retrieve(:back_present)).to be true
        expect(validation_context.retrieve(:back_red)).to eq(255)
        expect(validation_context.retrieve(:back_green)).to eq(128)
        expect(validation_context.retrieve(:back_blue)).to eq(0)
      end
    end

    context "with valid 7-byte BACK chunk" do
      it "accepts RGB with mandatory flag 0" do
        validation_context.store(:mhdr_present, true)
        data = [255, 128, 0].pack("nnn") + [0].pack("C")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be true
        expect(validation_context.errors).to be_empty
        expect(validation_context.retrieve(:back_mandatory)).to eq(0)
      end

      it "accepts RGB with mandatory flag 1" do
        validation_context.store(:mhdr_present, true)
        data = [255, 128, 0].pack("nnn") + [1].pack("C")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be true
        expect(validation_context.errors).to be_empty
        expect(validation_context.retrieve(:back_mandatory)).to eq(1)
      end
    end

    context "with valid 10-byte BACK chunk" do
      it "accepts full background specification" do
        validation_context.store(:mhdr_present, true)
        # RGB + mandatory + bg_image_id + tile_mode
        data = [255, 128, 0].pack("nnn") + [1].pack("C") +
          [5].pack("n") + [2].pack("C")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be true
        expect(validation_context.errors).to be_empty
        expect(validation_context.retrieve(:back_present)).to be true
        expect(validation_context.retrieve(:back_mandatory)).to eq(1)
        expect(validation_context.retrieve(:back_image_id)).to eq(5)
        expect(validation_context.retrieve(:back_tile_mode)).to eq(2)
      end
    end

    context "with invalid mandatory flag" do
      it "rejects mandatory flag 2" do
        validation_context.store(:mhdr_present, true)
        data = [255, 128, 0].pack("nnn") + [2].pack("C")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "BACK mandatory flag must be 0 or 1, got 2",
        )
      end
    end

    context "with invalid tile mode" do
      it "rejects tile mode 4" do
        validation_context.store(:mhdr_present, true)
        data = [255, 128, 0].pack("nnn") + [1].pack("C") +
          [5].pack("n") + [4].pack("C")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "BACK tile mode must be 0-3, got 4",
        )
      end
    end

    context "with invalid length" do
      it "rejects 0-byte BACK chunk" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([].pack("C*"))

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "BACK chunk must be 6, 7, or 10 bytes, got 0",
        )
      end

      it "rejects 8-byte BACK chunk" do
        validation_context.store(:mhdr_present, true)
        data = [255, 128, 0].pack("nnn") + [1, 0].pack("CC")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "BACK chunk must be 6, 7, or 10 bytes, got 8",
        )
      end
    end

    context "without MHDR" do
      it "rejects BACK before MHDR" do
        data = [255, 128, 0].pack("nnn")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "BACK must appear after MHDR",
        )
      end
    end

    context "after MEND" do
      it "rejects BACK after MEND" do
        validation_context.store(:mhdr_present, true)
        validation_context.record_chunk("MEND")
        data = [255, 128, 0].pack("nnn")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "BACK must appear before MEND",
        )
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        validation_context.store(:mhdr_present, true)
        data = [255, 128, 0].pack("nnn")
        allow(chunk).to receive_messages(crc_valid?: false, chunk_data: data)

        expect(validator.validate).to be false
      end
    end
  end
end
