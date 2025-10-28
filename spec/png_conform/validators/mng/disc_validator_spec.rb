# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Validators::Mng::DiscValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }
  let(:validator) { described_class.new(chunk, validation_context) }

  before do
    allow(chunk).to receive_messages(crc_valid?: true, chunk_type: "DISC",
                                     abs_offset: 700)
  end

  describe "#validate" do
    context "with valid DISC chunk" do
      it "accepts DISC with even length (multiple of 2)" do
        data = [0, 1, 0, 2].pack("C*") # 4 bytes (2 object IDs)
        allow(chunk).to receive(:chunk_data).and_return(data)
        validation_context.store(:mhdr_present, true)

        result = validator.validate

        expect(result).to be true
        expect(validation_context.errors.map { |e| e[:message] }).to be_empty
        expect(validation_context.retrieve(:disc_present)).to be true
      end

      it "accepts DISC with empty data" do
        allow(chunk).to receive(:chunk_data).and_return("")
        validation_context.store(:mhdr_present, true)

        result = validator.validate

        expect(result).to be true
        expect(validation_context.errors.map { |e| e[:message] }).to be_empty
        expect(validation_context.retrieve(:disc_present)).to be true
      end

      it "accepts DISC with multiple object IDs" do
        data = [0, 1, 0, 2, 0, 3, 0, 4, 0, 5].pack("C*") # 10 bytes (5 IDs)
        allow(chunk).to receive(:chunk_data).and_return(data)
        validation_context.store(:mhdr_present, true)

        result = validator.validate

        expect(result).to be true
        expect(validation_context.errors.map { |e| e[:message] }).to be_empty
        expect(validation_context.retrieve(:disc_present)).to be true
      end
    end

    context "with invalid length" do
      it "rejects DISC with odd length" do
        data = [0, 1, 0].pack("C*") # 3 bytes (invalid)
        allow(chunk).to receive(:chunk_data).and_return(data)
        validation_context.store(:mhdr_present, true)

        result = validator.validate

        expect(result).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "DISC chunk length must be a multiple of 2, got 3",
        )
      end
    end

    context "without MHDR" do
      it "rejects DISC before MHDR" do
        data = [0, 1].pack("C*")
        allow(chunk).to receive(:chunk_data).and_return(data)

        result = validator.validate

        expect(result).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "DISC must appear after MHDR",
        )
      end
    end

    context "ordering" do
      before do
        data = [0, 1].pack("C*")
        allow(chunk).to receive(:chunk_data).and_return(data)
        validation_context.store(:mhdr_present, true)
      end

      it "accepts DISC before MEND" do
        result = validator.validate

        expect(result).to be true
        expect(validation_context.errors.map { |e| e[:message] }).to be_empty
      end

      it "rejects DISC after MEND" do
        validation_context.record_chunk("MEND")

        result = validator.validate

        expect(result).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "DISC must appear before MEND",
        )
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive_messages(crc_valid?: false,
                                         chunk_data: [
                                           0, 1
                                         ].pack("C*"))

        result = validator.validate

        expect(result).to be false
      end
    end
  end
end
