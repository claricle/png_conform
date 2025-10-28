# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Validators::Mng::ClipValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }
  let(:validator) { described_class.new(chunk, validation_context) }

  before do
    allow(chunk).to receive_messages(crc_valid?: true, chunk_type: "CLIP",
                                     abs_offset: 0)
  end

  describe "#validate" do
    context "with valid CLIP chunk" do
      it "accepts 21-byte CLIP chunk" do
        validation_context.store(:mhdr_present, true)
        # First ID: 1, Last ID: 5, Type: 0, Left: 10, Right: 20, Top: 30,
        # Bottom: 40
        data = [1, 5, 0, 10, 20, 30, 40].pack("nnCl>l>l>l>")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be true
        expect(validation_context.errors).to be_empty
        expect(validation_context.retrieve(:clip_present)).to be true
        expect(validation_context.retrieve(:clip_first_id)).to eq(1)
        expect(validation_context.retrieve(:clip_last_id)).to eq(5)
        expect(validation_context.retrieve(:clip_type)).to eq(0)
        expect(validation_context.retrieve(:clip_left)).to eq(10)
        expect(validation_context.retrieve(:clip_right)).to eq(20)
        expect(validation_context.retrieve(:clip_top)).to eq(30)
        expect(validation_context.retrieve(:clip_bottom)).to eq(40)
      end

      it "accepts CLIP with negative deltas" do
        validation_context.store(:mhdr_present, true)
        # Negative deltas
        data = [0, 0, 0, -10, -20, -30, -40].pack("nnCl>l>l>l>")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be true
        expect(validation_context.errors).to be_empty
        expect(validation_context.retrieve(:clip_left)).to eq(-10)
        expect(validation_context.retrieve(:clip_right)).to eq(-20)
        expect(validation_context.retrieve(:clip_top)).to eq(-30)
        expect(validation_context.retrieve(:clip_bottom)).to eq(-40)
      end
    end

    context "with invalid length" do
      it "rejects CLIP with wrong length" do
        validation_context.store(:mhdr_present, true)
        data = [0] * 20
        allow(chunk).to receive(:chunk_data).and_return(data.pack("C*"))

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "CLIP chunk must be 21 bytes, got 20",
        )
      end

      it "rejects CLIP with 0 bytes" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return("")

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "CLIP chunk must be 21 bytes, got 0",
        )
      end
    end

    context "without MHDR" do
      it "rejects CLIP before MHDR" do
        data = [0, 0, 0, 0, 0, 0, 0].pack("nnCl>l>l>l>")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "CLIP must appear after MHDR",
        )
      end
    end

    context "after MEND" do
      it "rejects CLIP after MEND" do
        validation_context.store(:mhdr_present, true)
        validation_context.record_chunk("MEND")
        data = [0, 0, 0, 0, 0, 0, 0].pack("nnCl>l>l>l>")
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "CLIP must appear before MEND",
        )
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        validation_context.store(:mhdr_present, true)
        data = [0, 0, 0, 0, 0, 0, 0].pack("nnCl>l>l>l>")
        allow(chunk).to receive_messages(crc_valid?: false, chunk_data: data)

        expect(validator.validate).to be false
      end
    end
  end
end
