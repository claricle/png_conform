# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Validators::Mng::DefiValidator do
  let(:validation_context) { PngConform::Validators::ValidationContext.new }
  let(:chunk) { double("chunk") }

  before do
    allow(chunk).to receive_messages(crc_valid?: true, chunk_type: "DEFI",
                                     abs_offset: 0)
  end

  describe "#validate" do
    context "with valid 2-byte DEFI chunk" do
      it "accepts object ID only" do
        validation_context.store(:mhdr_present, true)
        # Object ID: 5
        allow(chunk).to receive(:chunk_data).and_return([5].pack("n"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:defi_present)).to be true
        expect(validation_context.retrieve(:defi_object_id)).to eq(5)
      end
    end

    context "with valid 3-byte DEFI chunk" do
      it "accepts object ID with do-not-show flag" do
        validation_context.store(:mhdr_present, true)
        # Object ID: 5, Do-not-show: 1
        allow(chunk).to receive(:chunk_data).and_return([5].pack("n") + [1].pack("C"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:defi_object_id)).to eq(5)
        expect(validation_context.retrieve(:defi_do_not_show)).to eq(1)
      end
    end

    context "with valid 4-byte DEFI chunk" do
      it "accepts object ID with do-not-show and concrete flags" do
        validation_context.store(:mhdr_present, true)
        # Object ID: 5, Do-not-show: 0, Concrete: 1
        data = [5].pack("n") + [0, 1].pack("CC")
        allow(chunk).to receive(:chunk_data).and_return(data)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:defi_object_id)).to eq(5)
        expect(validation_context.retrieve(:defi_do_not_show)).to eq(0)
        expect(validation_context.retrieve(:defi_concrete)).to eq(1)
      end
    end

    context "with valid 12-byte DEFI chunk" do
      it "accepts object ID with flags and location" do
        validation_context.store(:mhdr_present, true)
        # Object ID: 5, Do-not-show: 0, Concrete: 1, X: 100, Y: 200
        data = [5].pack("n") + [0, 1].pack("CC") + [100, 200].pack("NN")
        allow(chunk).to receive(:chunk_data).and_return(data)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:defi_object_id)).to eq(5)
        expect(validation_context.retrieve(:defi_x_location)).to eq(100)
        expect(validation_context.retrieve(:defi_y_location)).to eq(200)
      end
    end

    context "with valid 28-byte DEFI chunk" do
      it "accepts full specification with clipping boundaries" do
        validation_context.store(:mhdr_present, true)
        # Object ID: 5, Do-not-show: 0, Concrete: 1, X: 100, Y: 200
        # Clip: left=10, right=90, top=20, bottom=80
        data = [5].pack("n") + [0, 1].pack("CC") +
          [100, 200].pack("NN") + [10, 90, 20, 80].pack("NNNN")
        allow(chunk).to receive(:chunk_data).and_return(data)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
        expect(validation_context.retrieve(:defi_present)).to be true
        expect(validation_context.retrieve(:defi_object_id)).to eq(5)
        expect(validation_context.retrieve(:defi_x_location)).to eq(100)
        expect(validation_context.retrieve(:defi_y_location)).to eq(200)
        expect(validation_context.retrieve(:defi_clip_left)).to eq(10)
        expect(validation_context.retrieve(:defi_clip_right)).to eq(90)
        expect(validation_context.retrieve(:defi_clip_top)).to eq(20)
        expect(validation_context.retrieve(:defi_clip_bottom)).to eq(80)
      end
    end

    context "with invalid clipping boundaries" do
      it "rejects left > right" do
        validation_context.store(:mhdr_present, true)
        # Clip: left=90, right=10 (invalid)
        data = [5].pack("n") + [0, 1].pack("CC") +
          [100, 200].pack("NN") + [90, 10, 20, 80].pack("NNNN")
        allow(chunk).to receive(:chunk_data).and_return(data)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end

      it "rejects top > bottom" do
        validation_context.store(:mhdr_present, true)
        # Clip: top=80, bottom=20 (invalid)
        data = [5].pack("n") + [0, 1].pack("CC") +
          [100, 200].pack("NN") + [10, 90, 80, 20].pack("NNNN")
        allow(chunk).to receive(:chunk_data).and_return(data)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end

    context "with invalid length" do
      it "rejects 0-byte DEFI chunk" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive(:chunk_data).and_return("".b)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end

      it "rejects 5-byte DEFI chunk" do
        validation_context.store(:mhdr_present, true)
        data = [5].pack("n") + [0, 1, 0].pack("CCC")
        allow(chunk).to receive(:chunk_data).and_return(data)

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end

    context "without MHDR" do
      it "rejects DEFI before MHDR" do
        allow(chunk).to receive(:chunk_data).and_return([5].pack("n"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end

    context "with invalid CRC" do
      it "rejects chunk with bad CRC" do
        validation_context.store(:mhdr_present, true)
        allow(chunk).to receive_messages(crc_valid?: false,
                                         chunk_data: [5].pack("n"))

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end
  end

  describe "#validate (ordering)" do
    before do
      validation_context.store(:mhdr_present, true)
      allow(chunk).to receive(:chunk_data).and_return([5].pack("n"))
    end

    context "before MEND" do
      it "accepts DEFI chunk" do
        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be true
      end
    end

    context "after MEND" do
      it "rejects DEFI after MEND" do
        validation_context.record_chunk("MEND")

        validator = described_class.new(chunk, validation_context)
        expect(validator.validate).to be false
      end
    end
  end
end
