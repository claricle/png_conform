# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/apng/fdat_validator"

RSpec.describe PngConform::Validators::Apng::FdatValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  def create_fdat_chunk(sequence_number: 0, frame_data: "compressed_data",
crc_valid: true)
    data = [sequence_number].pack("N") + frame_data
    double(
      "fdAT Chunk",
      chunk_type: "fdAT",
      abs_offset: 200,
      chunk_data: data,
      crc_valid?: crc_valid,
    )
  end

  before do
    # Set up context for APNG
    context.store(:actl_num_frames, 10)
    context.store(:fctl_count, 1)
    context.store(:expected_apng_sequence, 1)
  end

  describe "constants" do
    it "defines CHUNK_TYPE" do
      expect(described_class::CHUNK_TYPE).to eq("fdAT")
    end

    it "defines MIN_LENGTH" do
      expect(described_class::MIN_LENGTH).to eq(5)
    end
  end

  describe "#validate" do
    context "with valid fdAT chunk" do
      it "validates successfully" do
        chunk = create_fdat_chunk(sequence_number: 1, frame_data: "test_data")
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
        expect(context.retrieve(:last_fdat_sequence)).to eq(1)
        expect(context.retrieve(:fdat_count)).to eq(1)
      end

      it "updates sequence counter" do
        chunk = create_fdat_chunk(sequence_number: 1)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.retrieve(:expected_apng_sequence)).to eq(2)
      end

      it "accumulates frame data length" do
        chunk1 = create_fdat_chunk(sequence_number: 1, frame_data: "12345")
        validator1 = described_class.new(chunk1, context)
        validator1.validate

        expect(context.retrieve(:fdat_data_length)).to eq(5)

        context.store(:expected_apng_sequence, 2)
        chunk2 = create_fdat_chunk(sequence_number: 2, frame_data: "678")
        validator2 = described_class.new(chunk2, context)
        validator2.validate

        expect(context.retrieve(:fdat_data_length)).to eq(8)
      end
    end

    context "with invalid CRC" do
      it "returns early without validating structure" do
        chunk = create_fdat_chunk(crc_valid: false)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.size).to eq(1)
        expect(context.errors.first[:message]).to include("CRC error")
      end
    end

    context "with invalid length" do
      it "rejects chunk that is too short" do
        data = [0].pack("N") # Only sequence number, no frame data
        chunk = double(
          "fdAT Chunk",
          chunk_type: "fdAT",
          abs_offset: 200,
          chunk_data: data,
          crc_valid?: true,
        )
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.size).to eq(1)
        expect(context.errors.first[:message]).to include("fdAT chunk too short")
      end

      it "accepts minimum valid length" do
        data = "#{[1].pack('N')}X" # Sequence number + 1 byte data (sequence 1 to match context)
        chunk = double(
          "fdAT Chunk",
          chunk_type: "fdAT",
          abs_offset: 200,
          chunk_data: data,
          crc_valid?: true,
        )
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
      end
    end

    context "with missing frame data" do
      it "rejects empty frame data after sequence number" do
        data = [0].pack("N").to_s
        chunk = double(
          "fdAT Chunk",
          chunk_type: "fdAT",
          abs_offset: 200,
          chunk_data: data,
          crc_valid?: true,
        )
        validator = described_class.new(chunk, context)

        validator.validate

        # Should fail the min length check
        expect(context.errors.size).to eq(1)
      end
    end

    context "without acTL chunk" do
      it "rejects fdAT" do
        context.store(:actl_num_frames, nil)
        chunk = create_fdat_chunk
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("requires acTL chunk")
        end).to be true
      end
    end

    context "without fcTL chunk" do
      it "rejects fdAT when fctl_count is zero" do
        context.store(:fctl_count, 0)
        chunk = create_fdat_chunk
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("requires fcTL chunk")
        end).to be true
      end

      it "rejects fdAT when no expected sequence set" do
        context.store(:expected_apng_sequence, nil)
        chunk = create_fdat_chunk
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("must follow fcTL chunk")
        end).to be true
      end
    end

    context "with sequence number violations" do
      it "rejects incorrect sequence number" do
        context.store(:expected_apng_sequence, 5)
        chunk = create_fdat_chunk(sequence_number: 1)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("sequence number mismatch")
        end).to be true
      end

      it "accepts correct sequence number" do
        context.store(:expected_apng_sequence, 3)
        chunk = create_fdat_chunk(sequence_number: 3)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
        expect(context.retrieve(:expected_apng_sequence)).to eq(4)
      end
    end

    context "with multiple fdAT chunks" do
      it "increments fdat_count correctly" do
        chunk1 = create_fdat_chunk(sequence_number: 1)
        validator1 = described_class.new(chunk1, context)
        validator1.validate

        expect(context.retrieve(:fdat_count)).to eq(1)

        context.store(:expected_apng_sequence, 2)
        chunk2 = create_fdat_chunk(sequence_number: 2)
        validator2 = described_class.new(chunk2, context)
        validator2.validate

        expect(context.retrieve(:fdat_count)).to eq(2)
      end

      it "tracks last_fdat_sequence" do
        chunk = create_fdat_chunk(sequence_number: 7)
        context.store(:expected_apng_sequence, 7)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.retrieve(:last_fdat_sequence)).to eq(7)
      end
    end

    context "with large frame data" do
      it "handles large frame data correctly" do
        large_data = "X" * 10000
        chunk = create_fdat_chunk(sequence_number: 1, frame_data: large_data)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
        expect(context.retrieve(:fdat_data_length)).to eq(10000)
      end
    end
  end
end
