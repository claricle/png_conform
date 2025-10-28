# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/mng/loop_validator"

RSpec.describe PngConform::Validators::Mng::LoopValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "LOOP", abs_offset: 400)
  end

  describe "#validate" do
    context "with valid LOOP chunk" do
      it "accepts 5-byte LOOP with basic iteration count" do
        data = [
          0, # nesting_level = 0
          0, 0, 0, 10 # iteration_count = 10
        ].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, length: 5,
                                         crc_valid?: true)
        validation_context.store(:mhdr_present, true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "accepts 6-byte LOOP with termination action" do
        data = [
          0, # nesting_level = 0
          0, 0, 0, 0, # iteration_count = 0 (infinite)
          1 # termination_action = 1
        ].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, length: 6,
                                         crc_valid?: true)
        validation_context.store(:mhdr_present, true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end

      it "tracks nesting level in loop_stack" do
        data = [1, 0, 0, 0, 5].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, length: 5,
                                         crc_valid?: true)
        validation_context.store(:mhdr_present, true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:loop_stack)).to eq([1])
      end
    end

    context "with invalid length" do
      it "rejects LOOP with wrong length" do
        data = [0, 0, 0, 5].pack("C*") # 4 bytes
        allow(chunk).to receive_messages(chunk_data: data, length: 4,
                                         crc_valid?: true)
        validation_context.store(:mhdr_present, true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
      end
    end

    context "without MHDR" do
      it "rejects LOOP before MHDR" do
        data = [0, 0, 0, 0, 10].pack("C*")
        allow(chunk).to receive_messages(chunk_data: data, length: 5,
                                         crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
      end
    end
  end

  describe "#validate (ordering)" do
    before do
      data = [0, 0, 0, 0, 10].pack("C*")
      allow(chunk).to receive_messages(chunk_data: data, length: 5,
                                       crc_valid?: true)
      validation_context.store(:mhdr_present, true)
    end

    it "accepts LOOP before MEND" do
      validator = described_class.new(chunk, validation_context)
      expect(validator.validate).to be true
      expect(validation_context.has_errors?).to be false
    end

    it "rejects LOOP after MEND" do
      validation_context.record_chunk("MEND")

      validator = described_class.new(chunk, validation_context)
      expect(validator.validate).to be false
      expect(validation_context.has_errors?).to be true
    end
  end
end
