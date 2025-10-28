# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Validators::Apng::FctlValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  def create_fctl_chunk(
    sequence_number: 0,
    width: 100,
    height: 100,
    x_offset: 0,
    y_offset: 0,
    delay_num: 1,
    delay_den: 10,
    dispose_op: 0,
    blend_op: 0,
    crc_valid: true
  )
    data = [
      sequence_number,
      width,
      height,
      x_offset,
      y_offset,
    ].pack("N5") + [delay_num,
                    delay_den].pack("n2") + [dispose_op, blend_op].pack("C2")

    double(
      "fcTL Chunk",
      chunk_type: "fcTL",
      abs_offset: 100,
      chunk_data: data,
      crc_valid?: crc_valid,
    )
  end

  before do
    # Set up IHDR context
    context.store(:ihdr_width, 640)
    context.store(:ihdr_height, 480)
    context.store(:actl_num_frames, 10)
    context.store(:expected_apng_sequence, 0)
  end

  describe "constants" do
    it "defines CHUNK_TYPE" do
      expect(described_class::CHUNK_TYPE).to eq("fcTL")
    end

    it "defines EXPECTED_LENGTH" do
      expect(described_class::EXPECTED_LENGTH).to eq(26)
    end

    it "defines dispose operations" do
      expect(described_class::DISPOSE_OP_NONE).to eq(0)
      expect(described_class::DISPOSE_OP_BACKGROUND).to eq(1)
      expect(described_class::DISPOSE_OP_PREVIOUS).to eq(2)
    end

    it "defines blend operations" do
      expect(described_class::BLEND_OP_SOURCE).to eq(0)
      expect(described_class::BLEND_OP_OVER).to eq(1)
    end
  end

  describe "#validate" do
    context "with valid fcTL chunk" do
      it "validates successfully" do
        chunk = create_fctl_chunk
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
        expect(context.retrieve(:last_fctl_sequence)).to eq(0)
        expect(context.retrieve(:fctl_count)).to eq(1)
      end

      it "updates sequence counter" do
        chunk = create_fctl_chunk(sequence_number: 0)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.retrieve(:expected_apng_sequence)).to eq(1)
      end
    end

    context "with invalid CRC" do
      it "returns early without validating structure" do
        chunk = create_fctl_chunk(crc_valid: false)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.size).to eq(1)
        expect(context.errors.first[:message]).to include("CRC error")
      end
    end

    context "with invalid length" do
      it "rejects chunk that is too short" do
        data = [0, 100, 100, 0, 0].pack("N5") # Missing delay and ops
        chunk = double(
          "fcTL Chunk",
          chunk_type: "fcTL",
          abs_offset: 100,
          chunk_data: data,
          crc_valid?: true,
        )
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.size).to eq(1)
        expect(context.errors.first[:message]).to include("invalid fcTL length")
      end
    end

    context "with zero dimensions" do
      it "rejects zero width" do
        chunk = create_fctl_chunk(width: 0)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("width and height must be > 0")
        end).to be true
      end

      it "rejects zero height" do
        chunk = create_fctl_chunk(height: 0)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("width and height must be > 0")
        end).to be true
      end
    end

    context "with invalid dispose operation" do
      it "rejects invalid dispose_op" do
        chunk = create_fctl_chunk(dispose_op: 99)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("invalid dispose_op")
        end).to be true
      end

      it "accepts DISPOSE_OP_NONE" do
        chunk = create_fctl_chunk(dispose_op: 0)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
      end

      it "accepts DISPOSE_OP_BACKGROUND" do
        chunk = create_fctl_chunk(dispose_op: 1)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
      end

      it "accepts DISPOSE_OP_PREVIOUS" do
        chunk = create_fctl_chunk(dispose_op: 2)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
      end
    end

    context "with invalid blend operation" do
      it "rejects invalid blend_op" do
        chunk = create_fctl_chunk(blend_op: 99)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("invalid blend_op")
        end).to be true
      end

      it "accepts BLEND_OP_SOURCE" do
        chunk = create_fctl_chunk(blend_op: 0)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
      end

      it "accepts BLEND_OP_OVER" do
        chunk = create_fctl_chunk(blend_op: 1)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
      end
    end

    context "with frame dimension violations" do
      it "rejects frame larger than IHDR width" do
        chunk = create_fctl_chunk(width: 1000)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("exceed IHDR dimensions")
        end).to be true
      end

      it "rejects frame larger than IHDR height" do
        chunk = create_fctl_chunk(height: 1000)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("exceed IHDR dimensions")
        end).to be true
      end

      it "rejects frame extending beyond IHDR width" do
        chunk = create_fctl_chunk(width: 100, x_offset: 600)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("extends beyond IHDR width")
        end).to be true
      end

      it "rejects frame extending beyond IHDR height" do
        chunk = create_fctl_chunk(height: 100, y_offset: 400)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("extends beyond IHDR height")
        end).to be true
      end

      it "accepts frame at maximum valid position" do
        chunk = create_fctl_chunk(width: 100, x_offset: 540, height: 100,
                                  y_offset: 380)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
      end
    end

    context "with sequence number violations" do
      it "requires acTL chunk" do
        context.store(:actl_num_frames, nil)
        chunk = create_fctl_chunk
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("requires acTL chunk")
        end).to be true
      end

      it "rejects incorrect sequence number" do
        context.store(:expected_apng_sequence, 5)
        chunk = create_fctl_chunk(sequence_number: 0)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("sequence number mismatch")
        end).to be true
      end

      it "accepts correct sequence number" do
        context.store(:expected_apng_sequence, 3)
        chunk = create_fctl_chunk(sequence_number: 3)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
        expect(context.retrieve(:expected_apng_sequence)).to eq(4)
      end
    end

    context "with delay calculations" do
      it "calculates delay with non-zero denominator" do
        chunk = create_fctl_chunk(delay_num: 5, delay_den: 100)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.retrieve(:frame_delay)).to eq(0.05)
      end

      it "uses default denominator when delay_den is zero" do
        chunk = create_fctl_chunk(delay_num: 5, delay_den: 0)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.retrieve(:frame_delay)).to eq(0.05)
      end
    end
  end
end
