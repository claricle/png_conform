# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/mng/fram_validator"

RSpec.describe PngConform::Validators::Mng::FramValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(crc_valid?: true, chunk_type: "FRAM",
                                     abs_offset: 0)
  end

  describe "#validate" do
    context "with valid 0-byte FRAM chunk" do
      it "accepts empty FRAM" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return("".b)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:fram_present)).to be true
      end
    end

    context "with valid 1-byte FRAM chunk" do
      it "accepts framing mode 0" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([0].pack("C"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:fram_framing_mode)).to eq(0)
      end

      it "accepts framing mode 4" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([4].pack("C"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:fram_framing_mode)).to eq(4)
      end
    end

    context "with FRAM containing subframe name" do
      it "accepts framing mode with 0-length name" do
        validation_context.store(:mhdr_present, true)
        # Framing mode: 1, Name length: 0
        allow(chunk).to receive(:chunk_data).and_return([1, 0].pack("C*"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:fram_framing_mode)).to eq(1)
      end

      it "accepts framing mode with subframe name" do
        validation_context.store(:mhdr_present, true)
        # Framing mode: 2, Name length: 5, Name: "frame"
        data = "#{[2, 5].pack('C*')}frame"
        allow(chunk).to receive(:chunk_data).and_return(data)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:fram_framing_mode)).to eq(2)
        expect(validation_context.retrieve(:fram_subframe_name)).to eq("frame")
      end
    end

    context "with FRAM containing parameters" do
      it "accepts framing mode with name and parameters" do
        validation_context.store(:mhdr_present, true)
        # Framing mode: 1, Name length: 3, Name: "abc", Parameters: [1, 2, 3]
        data = "#{[1, 3].pack('C*')}abc#{[1, 2, 3].pack('C*')}"
        allow(chunk).to receive(:chunk_data).and_return(data)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:fram_has_parameters)).to be true
      end
    end

    context "with invalid framing mode" do
      it "rejects framing mode 5" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([5].pack("C"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end

    context "with invalid subframe name" do
      it "rejects name extending beyond chunk" do
        validation_context.store(:mhdr_present, true)
        # Framing mode: 1, Name length: 10 (but only 2 bytes follow)
        data = "#{[1, 10].pack('C*')}ab"
        allow(chunk).to receive(:chunk_data).and_return(data)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end

    context "without MHDR" do
      it "rejects FRAM before MHDR" do
        allow(chunk).to receive(:chunk_data).and_return([0].pack("C"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive_messages(crc_valid?: false,
                                         chunk_data: [0].pack("C"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end
  end

  describe "#validate (ordering)" do
    before do
      validation_context.store(:mhdr_present, true)
      allow(chunk).to receive(:chunk_data).and_return([0].pack("C"))
    end

    context "before MEND" do
      it "accepts FRAM chunk" do
        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
      end
    end

    context "after MEND" do
      it "rejects FRAM after MEND" do
        validation_context.record_chunk("MEND")

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end
  end
end
