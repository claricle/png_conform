# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/base_validator"
require "png_conform/validators/mng/term_validator"

RSpec.describe PngConform::Validators::Mng::TermValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(chunk_type: "TERM", abs_offset: 700)
  end

  describe "#validate" do
    context "with valid 1-byte TERM chunk" do
      it "accepts termination action 0" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive_messages(chunk_data: [0].pack("C"),
                                         crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
        expect(validation_context.retrieve(:term_present)).to be true
        expect(validation_context.retrieve(:term_termination_action)).to eq(0)
      end

      it "accepts termination action 3" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive_messages(chunk_data: [3].pack("C"),
                                         crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
        expect(validation_context.retrieve(:term_termination_action)).to eq(3)
      end
    end

    context "with valid 10-byte TERM chunk" do
      it "accepts full termination specification" do
        validation_context.store(:mhdr_present, true)
        # Termination action: 1, After iterations: 2, Delay: 100, Max iterations: 10
        data = [1, 2].pack("C*") + [100].pack("N") + [10].pack("N")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
        expect(validation_context.retrieve(:term_present)).to be true
        expect(validation_context.retrieve(:term_termination_action)).to eq(1)
        expect(validation_context.retrieve(:term_after_iterations)).to eq(2)
        expect(validation_context.retrieve(:term_delay)).to eq(100)
        expect(validation_context.retrieve(:term_max_iterations)).to eq(10)
      end
    end

    context "with invalid termination action" do
      it "rejects termination action 4" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive_messages(chunk_data: [4].pack("C"),
                                         crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include(
          "Invalid TERM termination action: 4 (must be 0-3)",
        )
      end
    end

    context "with invalid after_iterations" do
      it "rejects after_iterations value 3" do
        validation_context.store(:mhdr_present, true)
        # Termination action: 1, After iterations: 3 (invalid), Delay: 0, Max iterations: 0
        data = [1, 3].pack("C*") + [0].pack("N") + [0].pack("N")
        allow(chunk).to receive_messages(chunk_data: data, crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include(
          "Invalid TERM action after iterations: 3 (must be 0-2)",
        )
      end
    end

    context "with invalid length" do
      it "rejects 0-byte TERM chunk" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive_messages(chunk_data: [].pack("C*"),
                                         crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include(
          "TERM chunk must be 1 or 10 bytes, got 0",
        )
      end

      it "rejects 5-byte TERM chunk" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive_messages(chunk_data: [0, 0, 0, 0,
                                                      0].pack("C*"), crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include(
          "TERM chunk must be 1 or 10 bytes, got 5",
        )
      end
    end

    context "without MHDR" do
      it "rejects TERM before MHDR" do
        allow(chunk).to receive_messages(chunk_data: [0].pack("C"),
                                         crc_valid?: true)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("TERM must appear after MHDR")
      end
    end
  end

  describe "#validate (ordering)" do
    before do
      validation_context.store(:mhdr_present, true)
      allow(chunk).to receive_messages(chunk_data: [0].pack("C"),
                                       crc_valid?: true)
    end

    context "before MEND" do
      it "accepts TERM chunk" do
        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.has_errors?).to be false
      end
    end

    context "after MEND" do
      it "rejects TERM after MEND" do
        validation_context.record_chunk("MEND")

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
        expect(validation_context.has_errors?).to be true
        expect(validation_context.all_errors.first[:message]).to include("TERM must appear before MEND")
      end
    end
  end
end
