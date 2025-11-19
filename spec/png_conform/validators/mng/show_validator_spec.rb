# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/mng/show_validator"

RSpec.describe PngConform::Validators::Mng::ShowValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }
  let(:validator) { described_class.new(chunk, validation_context) }

  before do
    allow(chunk).to receive_messages(crc_valid?: true, chunk_type: "SHOW",
                                     abs_offset: 0)
  end

  describe "#validate" do
    context "with valid 0-byte SHOW chunk" do
      it "accepts empty data when MHDR is present" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return("")

        expect(validator.validate).to be true
        expect(validation_context.errors).to be_empty
        expect(validation_context.retrieve(:show_present)).to be true
      end
    end

    context "with valid 2-byte SHOW chunk" do
      it "accepts 2-byte object ID when MHDR is present" do
        validation_context.store(:mhdr_present, true)
        data = [5].pack("n") # Object ID: 5
        allow(chunk).to receive(:chunk_data).and_return(data)

        expect(validator.validate).to be true
        expect(validation_context.errors).to be_empty
        expect(validation_context.retrieve(:show_present)).to be true
        expect(validation_context.retrieve(:show_object_id)).to eq(5)
      end
    end

    context "with invalid length" do
      it "rejects 1-byte SHOW chunk" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([0].pack("C*"))

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "SHOW chunk must be 0 or 2 bytes, got 1",
        )
      end

      it "rejects 3-byte SHOW chunk" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([0, 1, 2].pack("C*"))

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "SHOW chunk must be 0 or 2 bytes, got 3",
        )
      end
    end

    context "without MHDR" do
      it "rejects SHOW before MHDR" do
        allow(chunk).to receive(:chunk_data).and_return("")

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "SHOW must appear after MHDR",
        )
      end
    end

    context "after MEND" do
      it "rejects SHOW after MEND" do
        validation_context.store(:mhdr_present, true)
        validation_context.record_chunk("MEND")
        allow(chunk).to receive(:chunk_data).and_return("")

        expect(validator.validate).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "SHOW must appear before MEND",
        )
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive_messages(crc_valid?: false, chunk_data: "")

        expect(validator.validate).to be false
      end
    end
  end
end
