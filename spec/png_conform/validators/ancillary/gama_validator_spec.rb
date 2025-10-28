# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Validators::Ancillary::GamaValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  describe "#validate" do
    context "with valid gAMA chunk" do
      it "accepts gamma value of 45455 (1/2.2)" do
        chunk = create_chunk("gAMA", [45_455].pack("N"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
        expect(context.gamma).to eq(45_455)
      end

      it "accepts gamma value of 100000 (1.0)" do
        chunk = create_chunk("gAMA", [100_000].pack("N"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
        expect(context.gamma).to eq(100_000)
      end

      it "accepts gamma value of 50000 (2.0)" do
        chunk = create_chunk("gAMA", [50_000].pack("N"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end
    end

    context "with invalid chunk length" do
      it "rejects gAMA with length < 4" do
        chunk = create_chunk("gAMA", [100].pack("n"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/invalid gAMA length/i)
      end

      it "rejects gAMA with length > 4" do
        chunk = create_chunk("gAMA", [45_455, 0].pack("NN"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/invalid gAMA length/i)
      end
    end

    context "with invalid gamma value" do
      it "rejects gamma value of 0" do
        chunk = create_chunk("gAMA", [0].pack("N"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/invalid gAMA value/i)
      end
    end

    context "with sRGB chunk present" do
      before do
        context.record_chunk("sRGB")
      end

      it "warns if gAMA != 45455 (not 1/2.2)" do
        chunk = create_chunk("gAMA", [50_000].pack("N"))
        described_class.new(chunk, context).validate

        expect(context.has_warnings?).to be true
        expect(context.all_warnings.first[:message]).to match(/sRGB.*45455|gamma/i)
      end

      it "accepts gAMA = 45455 with sRGB present" do
        chunk = create_chunk("gAMA", [45_455].pack("N"))
        described_class.new(chunk, context).validate

        expect(context.has_warnings?).to be false
      end
    end

    context "chunk ordering" do
      it "appears before PLTE if PLTE is present" do
        context.record_chunk("PLTE")
        chunk = create_chunk("gAMA", [45_455].pack("N"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/after PLTE.*before/i)
      end

      it "appears before IDAT" do
        context.record_chunk("IDAT")
        chunk = create_chunk("gAMA", [45_455].pack("N"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/IDAT/i)
      end

      it "accepts gAMA before PLTE and IDAT" do
        chunk = create_chunk("gAMA", [45_455].pack("N"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end
    end

    context "multiple gAMA chunks" do
      before do
        context.record_chunk("gAMA")
      end

      it "rejects multiple gAMA chunks" do
        chunk = create_chunk("gAMA", [50_000].pack("N"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/duplicate.*gAMA/i)
      end
    end
  end

  def create_chunk(type, data)
    PngConform::Models::ChunkInfo.new(
      type: type,
      length: data.bytesize,
      data: data,
      crc: 0,
      offset: 0,
      crc_valid: true,
    )
  end
end
