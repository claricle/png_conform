# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Validators::Ancillary::PcalValidator do
  let(:context) { PngConform::Validators::ValidationContext.new }

  before do
    context.width = 100
    context.height = 100
    context.color_type = 2
    context.bit_depth = 8
  end

  describe "#validate" do
    context "with valid PCAL chunk" do
      it "accepts valid data" do
        # pCAL format: name\0 + orig_zero(4) + orig_max(4) + eq_type(1) + num_params(1) + unit\0 + params\0...
        data = "Test\x00"
        data += [-100].pack("N")  # Original zero (signed 32-bit big-endian)
        data += [100].pack("N")   # Original max (signed 32-bit big-endian)
        data += "\x00"            # Equation type 0 (linear)
        data += "\x02"            # Number of parameters (2)
        data += "m\x00"           # Unit name
        data += "1.0\x00"         # Parameter 1
        data += "2.0\x00"         # Parameter 2

        chunk = create_chunk("pCAL", data)
        validator = described_class.new(chunk, context)

        expect(validator.validate).to be true
        expect(context.has_errors?).to be false
      end
    end

    context "with invalid chunk data" do
      it "rejects invalid data format" do
        chunk = create_chunk("pCAL", "Invalid")
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
      end
    end

    context "chunk ordering" do
      it "must appear before IDAT" do
        context.record_chunk("IDAT")

        data = "Test\x00"
        data += [-100].pack("N")
        data += [100].pack("N")
        data += "\x00"
        data += "\x02"
        data += "m\x00"
        data += "1.0\x00"
        data += "2.0\x00"

        chunk = create_chunk("pCAL", data)
        described_class.new(chunk, context).validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/IDAT/i)
      end
    end

    context "multiple PCAL chunks" do
      it "rejects multiple PCAL chunks" do
        # First pCAL chunk with proper format
        data = "Test\x00"
        data += [-100].pack("N")
        data += [100].pack("N")
        data += "\x00"
        data += "\x02"
        data += "m\x00"
        data += "1.0\x00"
        data += "2.0\x00"

        chunk1 = create_chunk("pCAL", data)
        validator1 = described_class.new(chunk1, context)
        validator1.validate

        # Second pCAL chunk - should fail
        chunk2 = create_chunk("pCAL", data)
        validator2 = described_class.new(chunk2, context)
        validator2.validate

        expect(context.has_errors?).to be true
        expect(context.all_errors.first[:message]).to match(/duplicate.*pCAL/i)
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
