# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/mng/endl_validator"

RSpec.describe PngConform::Validators::Mng::EndlValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "ENDL", abs_offset: 500)
  end

  describe "#validate" do
    context "with valid ENDL chunk" do
      it "accepts 1-byte ENDL matching LOOP nesting level" do
        data = [0].pack("C*")  # nesting_level = 0
        allow(chunk).to receive_messages(chunk_data: data, length: 1,
                                         crc_valid?: true)
        validation_context.store(:mhdr_present, true)
        validation_context.store(:loop_present, true)
        validation_context.store(:loop_stack, [0])

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "pops nesting level from loop_stack" do
        data = [1].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, length: 1,
                                         crc_valid?: true)
        validation_context.store(:mhdr_present, true)
        validation_context.store(:loop_present, true)
        validation_context.store(:loop_stack, [0, 1])

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:loop_stack)).to eq([0])
      end
    end

    context "with mismatched nesting level" do
      it "rejects ENDL with wrong nesting level" do
        data = [1].pack("C*")  # nesting_level = 1
        allow(chunk).to receive_messages(chunk_data: data, length: 1,
                                         crc_valid?: true)
        validation_context.store(:mhdr_present, true)
        validation_context.store(:loop_present, true)
        validation_context.store(:loop_stack, [0]) # expecting 0, got 1

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
      end
    end

    context "without corresponding LOOP" do
      it "rejects ENDL without LOOP" do
        data = [0].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, length: 1,
                                         crc_valid?: true)
        validation_context.store(:mhdr_present, true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
      end
    end

    context "with invalid length" do
      it "rejects ENDL with wrong length" do
        data = [0, 0].pack("C*") # 2 bytes instead of 1
        allow(chunk).to receive_messages(chunk_data: data, length: 2,
                                         crc_valid?: true)
        validation_context.store(:mhdr_present, true)
        validation_context.store(:loop_present, true)
        validation_context.store(:loop_stack, [0])

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
      end
    end
  end

  describe "#validate (ordering)" do
    before do
      data = [0].pack("C*")
      allow(chunk).to receive_messages(chunk_data: data, length: 1,
                                       crc_valid?: true)
      validation_context.store(:mhdr_present, true)
      validation_context.store(:loop_present, true)
      validation_context.store(:loop_stack, [0])
    end

    it "accepts ENDL before MEND" do
      validator = described_class.new(chunk, validation_context)
      expect(validator.validate).to be true
      expect(validation_context.has_errors?).to be false
    end

    it "rejects ENDL after MEND" do
      validation_context.record_chunk("MEND")

      validator = described_class.new(chunk, validation_context)
      expect(validator.validate).to be false
      expect(validation_context.has_errors?).to be true
    end
  end
end
