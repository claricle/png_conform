# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/mng/move_validator"

RSpec.describe PngConform::Validators::Mng::MoveValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }
  let(:validator) { described_class.new(chunk, validation_context) }

  before do
    allow(chunk).to receive_messages(crc_valid?: true, chunk_type: "MOVE",
                                     abs_offset: 0)
  end

  describe "#validate" do
    context "with valid MOVE chunk" do
      it "accepts 13-byte MOVE chunk" do
        validation_context.store(:mhdr_present, true)
        # First ID: 1, Last ID: 5, Type: 0, X: 100, Y: 200
        data = [1, 5, 0, 100, 200].pack("nnCl>l>")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be true
        expect(validation_context.errors).to be_empty
        expect(validation_context.retrieve(:move_present)).to be true
        expect(validation_context.retrieve(:move_first_id)).to eq(1)
        expect(validation_context.retrieve(:move_last_id)).to eq(5)
        expect(validation_context.retrieve(:move_type)).to eq(0)
        expect(validation_context.retrieve(:move_x_offset)).to eq(100)
        expect(validation_context.retrieve(:move_y_offset)).to eq(200)
      end

      it "accepts MOVE with negative offsets" do
        validation_context.store(:mhdr_present, true)
        # Negative X and Y offsets
        data = [0, 0, 0, -50, -75].pack("nnCl>l>")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be true
        expect(validation_context.errors).to be_empty
        expect(validation_context.retrieve(:move_x_offset)).to eq(-50)
        expect(validation_context.retrieve(:move_y_offset)).to eq(-75)
      end
    end

    context "with invalid length" do
      it "rejects MOVE with wrong length" do
        validation_context.store(:mhdr_present, true)
        data = [0, 1, 0, 0, 0, 100].pack("C*") # 6 bytes instead of 13
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "MOVE chunk must be 13 bytes, got 6",
        )
      end

      it "rejects MOVE with 0 bytes" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return("")

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "MOVE chunk must be 13 bytes, got 0",
        )
      end
    end

    context "without MHDR" do
      it "rejects MOVE before MHDR" do
        data = [0, 0, 0, 0, 0].pack("nnCl>l>")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "MOVE must appear after MHDR",
        )
      end
    end

    context "after MEND" do
      it "rejects MOVE after MEND" do
        validation_context.store(:mhdr_present, true)
        validation_context.record_chunk("MEND")
        data = [0, 0, 0, 0, 0].pack("nnCl>l>")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "MOVE must appear before MEND",
        )
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        validation_context.store(:mhdr_present, true)
        data = [0, 0, 0, 0, 0].pack("nnCl>l>")
        allow(chunk).to receive_messages(crc_valid?: false, chunk_data: data)

        expect(validator.validate).to be false
      end
    end
  end
end
