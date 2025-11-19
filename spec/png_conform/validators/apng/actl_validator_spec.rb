# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/apng/actl_validator"

RSpec.describe PngConform::Validators::Apng::ActlValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  def create_actl_chunk(num_frames:, num_plays:, crc_valid: true)
    data = [num_frames, num_plays].pack("N2")
    double(
      "acTL Chunk",
      chunk_type: "acTL",
      abs_offset: 8,
      chunk_data: data,
      crc_valid?: crc_valid,
    )
  end

  describe "constants" do
    it "defines CHUNK_TYPE" do
      expect(described_class::CHUNK_TYPE).to eq("acTL")
    end

    it "defines EXPECTED_LENGTH" do
      expect(described_class::EXPECTED_LENGTH).to eq(8)
    end
  end

  describe "#validate" do
    context "with valid acTL chunk" do
      it "validates successfully" do
        chunk = create_actl_chunk(num_frames: 10, num_plays: 0)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
        expect(context.retrieve(:actl_num_frames)).to eq(10)
        expect(context.retrieve(:actl_num_plays)).to eq(0)
      end

      it "accepts finite loop count" do
        chunk = create_actl_chunk(num_frames: 5, num_plays: 3)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
        expect(context.retrieve(:actl_num_plays)).to eq(3)
      end
    end

    context "with invalid CRC" do
      it "returns early without validating structure" do
        chunk = create_actl_chunk(num_frames: 10, num_plays: 0,
                                  crc_valid: false)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.size).to eq(1)
        expect(context.errors.first[:message]).to include("CRC error")
      end
    end

    context "with invalid length" do
      it "rejects chunk that is too short" do
        data = [10].pack("N") # Only 4 bytes instead of 8
        chunk = double(
          "acTL Chunk",
          chunk_type: "acTL",
          abs_offset: 8,
          chunk_data: data,
          crc_valid?: true,
        )
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.size).to eq(1)
        expect(context.errors.first[:message]).to include("invalid acTL length")
      end

      it "rejects chunk that is too long" do
        data = [10, 0, 99].pack("N3") # 12 bytes instead of 8
        chunk = double(
          "acTL Chunk",
          chunk_type: "acTL",
          abs_offset: 8,
          chunk_data: data,
          crc_valid?: true,
        )
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.size).to eq(1)
        expect(context.errors.first[:message]).to include("invalid acTL length")
      end
    end

    context "with zero num_frames" do
      it "rejects the chunk" do
        chunk = create_actl_chunk(num_frames: 0, num_plays: 0)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.size).to eq(1)
        expect(context.errors.first[:message]).to include("num_frames must be > 0")
      end
    end

    context "with ordering violations" do
      it "rejects acTL appearing after IDAT" do
        context.record_chunk("IDAT")
        chunk = create_actl_chunk(num_frames: 10, num_plays: 0)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("must appear before IDAT")
        end).to be true
      end

      it "rejects acTL appearing after fcTL" do
        context.record_chunk("fcTL")
        chunk = create_actl_chunk(num_frames: 10, num_plays: 0)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors.any? do |e|
          e[:message].include?("must appear before first fcTL")
        end).to be true
      end

      it "allows acTL before IDAT and fcTL" do
        chunk = create_actl_chunk(num_frames: 10, num_plays: 0)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
      end
    end

    context "with edge case values" do
      it "accepts maximum num_frames value" do
        chunk = create_actl_chunk(num_frames: 0xFFFFFFFF, num_plays: 0)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
        expect(context.retrieve(:actl_num_frames)).to eq(0xFFFFFFFF)
      end

      it "accepts maximum num_plays value" do
        chunk = create_actl_chunk(num_frames: 1, num_plays: 0xFFFFFFFF)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
        expect(context.retrieve(:actl_num_plays)).to eq(0xFFFFFFFF)
      end

      it "accepts single frame animation" do
        chunk = create_actl_chunk(num_frames: 1, num_plays: 1)
        validator = described_class.new(chunk, context)

        validator.validate

        expect(context.errors).to be_empty
      end
    end
  end
end
