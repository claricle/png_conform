# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Validators::Mng::ClonValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }
  let(:validator) { described_class.new(chunk, validation_context) }

  before do
    allow(chunk).to receive_messages(crc_valid?: true, chunk_type: "CLON",
                                     abs_offset: 100)
  end

  describe "#validate" do
    context "with valid 4-byte CLON chunk" do
      it "accepts 4-byte clone specification when MHDR is present" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([0, 1, 0, 2].pack("C*"))

        result = validator.validate

        expect(result).to be true
        expect(validation_context.errors.map { |e| e[:message] }).to be_empty
        expect(validation_context.retrieve(:clon_present)).to be true
      end
    end

    context "with valid 16-byte CLON chunk" do
      it "accepts 16-byte clone specification when MHDR is present" do
        validation_context.store(:mhdr_present, true)
        data = [0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0].pack("C*")
        allow(chunk).to receive(:chunk_data).and_return(data)

        result = validator.validate

        expect(result).to be true
        expect(validation_context.errors.map { |e| e[:message] }).to be_empty
        expect(validation_context.retrieve(:clon_present)).to be true
      end
    end

    context "with invalid length" do
      it "rejects 0-byte CLON chunk" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([].pack("C*"))

        result = validator.validate

        expect(result).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "CLON chunk must be 4 or 16 bytes, got 0",
        )
      end

      it "rejects 8-byte CLON chunk" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([0, 1, 0, 2, 0, 0, 0,
                                                         0].pack("C*"))

        result = validator.validate

        expect(result).to be false
        expect(validation_context.errors.map { |e| e[:message] }).to include(
          "CLON chunk must be 4 or 16 bytes, got 8",
        )
      end
    end

    context "without MHDR" do
      it "rejects CLON before MHDR" do
        allow(chunk).to receive(:chunk_data).and_return([0, 1, 0, 2].pack("C*"))

        result = validator.validate

        expect(result).to be false
        expect(validation_context.errors.map do |e|
          e[:message]
        end).to include("CLON must appear after MHDR")
      end
    end

    context "ordering" do
      before do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([0, 1, 0, 2].pack("C*"))
      end

      it "accepts CLON before MEND" do
        result = validator.validate

        expect(result).to be true
        expect(validation_context.errors.map { |e| e[:message] }).to be_empty
      end

      it "rejects CLON after MEND" do
        validation_context.record_chunk("MEND")

        result = validator.validate

        expect(result).to be false
        expect(validation_context.errors.map do |e|
          e[:message]
        end).to include("CLON must appear before MEND")
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive_messages(crc_valid?: false,
                                         chunk_data: [
                                           0, 1, 0, 2
                                         ].pack("C*"))

        result = validator.validate

        expect(result).to be false
      end
    end
  end
end
