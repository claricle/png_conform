# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Validators::Mng::DhdrValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(crc_valid?: true, chunk_type: "DHDR",
                                     abs_offset: 0)
  end

  describe "#validate" do
    context "with valid 4-byte DHDR chunk" do
      it "accepts object ID only" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([5].pack("N"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:dhdr_present)).to be true
        expect(validation_context.retrieve(:dhdr_object_id)).to eq(5)
      end
    end

    context "with valid 12-byte DHDR chunk" do
      it "accepts object ID with image type and delta type" do
        validation_context.store(:mhdr_present, true)
        # Object ID: 5, Image type: 0 (PNG), Delta type: 1
        allow(chunk).to receive(:chunk_data).and_return([5, 0, 1].pack("N*"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:dhdr_object_id)).to eq(5)
        expect(validation_context.retrieve(:dhdr_image_type)).to eq(0)
        expect(validation_context.retrieve(:dhdr_delta_type)).to eq(1)
      end

      it "accepts image type 2 (JNG)" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([5, 2, 0].pack("N*"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:dhdr_image_type)).to eq(2)
      end

      it "accepts image type 4 (PNG with alpha separation)" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([5, 4, 0].pack("N*"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:dhdr_image_type)).to eq(4)
      end
    end

    context "with valid 20-byte DHDR chunk" do
      it "accepts full specification with block dimensions" do
        validation_context.store(:mhdr_present, true)
        # Object ID: 5, Image type: 0, Delta type: 1, Block width: 32, Block height: 32
        data = [5, 0, 1, 32, 32].pack("N*")
        allow(chunk).to receive(:chunk_data).and_return(data)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:dhdr_present)).to be true
        expect(validation_context.retrieve(:dhdr_object_id)).to eq(5)
        expect(validation_context.retrieve(:dhdr_image_type)).to eq(0)
        expect(validation_context.retrieve(:dhdr_delta_type)).to eq(1)
        expect(validation_context.retrieve(:dhdr_block_width)).to eq(32)
        expect(validation_context.retrieve(:dhdr_block_height)).to eq(32)
      end
    end

    context "with invalid image type" do
      it "rejects image type 1" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([5, 1, 0].pack("N*"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end

    context "with invalid delta type" do
      it "rejects delta type 8" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([5, 0, 8].pack("N*"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end

    context "with invalid block dimensions" do
      it "rejects block width of 0" do
        validation_context.store(:mhdr_present, true)
        data = [5, 0, 1, 0, 32].pack("N*")
        allow(chunk).to receive(:chunk_data).and_return(data)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end

      it "rejects block height of 0" do
        validation_context.store(:mhdr_present, true)
        data = [5, 0, 1, 32, 0].pack("N*")
        allow(chunk).to receive(:chunk_data).and_return(data)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end

    context "with invalid length" do
      it "rejects 0-byte DHDR chunk" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return("".b)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end

      it "rejects 8-byte DHDR chunk" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return([5, 0].pack("N*"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end

    context "without MHDR" do
      it "rejects DHDR before MHDR" do
        allow(chunk).to receive(:chunk_data).and_return([5].pack("N"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive_messages(crc_valid?: false,
                                         chunk_data: [5].pack("N"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end
  end

  describe "#validate (ordering)" do
    before do
      validation_context.store(:mhdr_present, true)
      allow(chunk).to receive(:chunk_data).and_return([5].pack("N"))
    end

    context "before MEND" do
      it "accepts DHDR chunk and marks in_dhdr_section" do
        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:in_dhdr_section)).to be true
      end
    end

    context "after MEND" do
      it "rejects DHDR after MEND" do
        validation_context.record_chunk("MEND")

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end
  end
end
