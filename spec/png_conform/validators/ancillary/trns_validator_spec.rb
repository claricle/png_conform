# frozen_string_literal: true

require "spec_helper"
require "png_conform/validators/ancillary/trns_validator"

RSpec.describe PngConform::Validators::Ancillary::TrnsValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  before do
    context.width = 100
    context.height = 100
  end

  describe "#validate" do
    context "with grayscale image (color type 0)" do
      before do
        context.color_type = 0
        context.bit_depth = 8
      end

      it "accepts valid 2-byte gray value" do
        chunk = create_chunk("tRNS", [128].pack("n"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end

      it "rejects incorrect length" do
        chunk = create_chunk("tRNS", [128].pack("N"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/invalid tRNS length/i)
      end
    end

    context "with RGB image (color type 2)" do
      before do
        context.color_type = 2
        context.bit_depth = 8
      end

      it "accepts valid 6-byte RGB values" do
        chunk = create_chunk("tRNS", [255, 128, 64].pack("nnn"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end

      it "rejects incorrect length" do
        chunk = create_chunk("tRNS", [255, 128].pack("nn"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/invalid tRNS length/i)
      end
    end

    context "with indexed color image (color type 3)" do
      before do
        context.color_type = 3
        context.bit_depth = 8
        context.store(:has_palette, true)
        context.store(:palette_entries, 4)
        context.record_chunk("PLTE")
      end

      it "accepts alpha values for palette entries" do
        chunk = create_chunk("tRNS", [255, 128, 64, 0].pack("C*"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end

      it "accepts fewer alpha values than palette entries" do
        chunk = create_chunk("tRNS", [255, 128].pack("C*"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be false
      end

      it "rejects more alpha values than palette entries" do
        chunk = create_chunk("tRNS", [255, 128, 64, 0, 32].pack("C*"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/more entries than palette/i)
      end

      it "requires PLTE chunk to be present" do
        # Clear the has_palette flag to simulate no PLTE
        context.store(:has_palette, false)
        chunk = create_chunk("tRNS", [255].pack("C"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/without PLTE chunk/i)
      end
    end

    context "with images that have native alpha" do
      it "rejects tRNS for grayscale+alpha (color type 4)" do
        context.color_type = 4
        chunk = create_chunk("tRNS", [128].pack("n"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/not allowed.*alpha channel/i)
      end

      it "rejects tRNS for RGB+alpha (color type 6)" do
        context.color_type = 6
        chunk = create_chunk("tRNS", [255, 128, 64].pack("nnn"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/not allowed.*alpha channel/i)
      end
    end

    context "chunk ordering" do
      before do
        context.color_type = 2
      end

      it "must appear after PLTE for indexed images" do
        context.color_type = 3
        context.palette_size = 4
        context.plte_seen = false
        chunk = create_chunk("tRNS", [255, 128].pack("C*"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/before PLTE/i)
      end

      it "must appear before IDAT" do
        context.record_chunk("IDAT")
        chunk = create_chunk("tRNS", [255, 128, 64].pack("nnn"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/IDAT/i)
      end
    end

    context "multiple tRNS chunks" do
      before do
        context.color_type = 2
        context.store(:has_transparency, true)
      end

      it "rejects multiple tRNS chunks" do
        chunk = create_chunk("tRNS", [100, 50, 25].pack("nnn"))
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/duplicate.*tRNS/i)
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
