# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Validators::BaseValidator do
  let(:chunk) do
    double(
      "Chunk",
      chunk_type: "TEST",
      abs_offset: 100,
      chunk_data: "test data",
      crc_valid?: true,
    )
  end

  let(:context) { PngConform::Validators::ValidationContext.new }
  let(:validator) { described_class.new(chunk, context) }

  describe "#initialize" do
    it "accepts chunk and context" do
      expect(validator.chunk).to eq(chunk)
      expect(validator.context).to eq(context)
    end

    it "creates default context when not provided" do
      validator_without_context = described_class.new(chunk)
      expect(validator_without_context.context).to be_a(
        PngConform::Validators::ValidationContext,
      )
    end
  end

  describe "#validate" do
    it "raises NotImplementedError" do
      expect { validator.validate }.to raise_error(
        NotImplementedError,
        "Subclasses must implement #validate",
      )
    end
  end

  describe "#add_error" do
    it "adds error to context with default severity" do
      validator.send(:add_error, "test error")
      expect(context.errors.size).to eq(1)
      expect(context.errors.first[:message]).to eq("test error")
      expect(context.errors.first[:severity]).to eq(:error)
      expect(context.errors.first[:chunk_type]).to eq("TEST")
      expect(context.errors.first[:offset]).to eq(100)
    end

    it "adds error with custom severity" do
      validator.send(:add_error, "test warning", severity: :warning)
      expect(context.errors.first[:severity]).to eq(:warning)
    end
  end

  describe "#add_warning" do
    it "adds warning to context" do
      validator.send(:add_warning, "test warning")
      expect(context.errors.size).to eq(1)
      expect(context.errors.first[:severity]).to eq(:warning)
    end
  end

  describe "#add_info" do
    it "adds info to context" do
      validator.send(:add_info, "test info")
      expect(context.errors.size).to eq(1)
      expect(context.errors.first[:severity]).to eq(:info)
    end
  end

  describe "#check_length" do
    it "returns true when length matches" do
      # Create chunk with correct length data
      chunk_with_correct_length = double(
        "Chunk",
        chunk_type: "TEST",
        abs_offset: 100,
        chunk_data: "123456789", # 9 bytes
        crc_valid?: true,
      )
      validator_with_correct = described_class.new(chunk_with_correct_length,
                                                   context)
      expect(validator_with_correct.send(:check_length, 9)).to be true
      expect(context.errors).to be_empty
    end

    it "returns false and adds error when length doesn't match" do
      # Create chunk with wrong length data
      chunk_with_wrong_length = double(
        "Chunk",
        chunk_type: "TEST",
        abs_offset: 100,
        chunk_data: "12345", # 5 bytes instead of 9
        crc_valid?: true,
      )
      validator_with_wrong = described_class.new(chunk_with_wrong_length,
                                                 context)
      expect(validator_with_wrong.send(:check_length, 9)).to be false
      expect(context.errors.size).to eq(1)
      expect(context.errors.first[:message]).to include(
        "invalid TEST length (5, should be 9)",
      )
    end
  end

  describe "#check_range" do
    it "returns true when value is in range" do
      expect(validator.send(:check_range, 5, 1, 10, "test value")).to be true
      expect(context.errors).to be_empty
    end

    it "returns true when value equals min" do
      expect(validator.send(:check_range, 1, 1, 10, "test value")).to be true
    end

    it "returns true when value equals max" do
      expect(validator.send(:check_range, 10, 1, 10, "test value")).to be true
    end

    it "returns false when value is below min" do
      expect(validator.send(:check_range, 0, 1, 10, "test value")).to be false
      expect(context.errors.first[:message]).to include(
        "invalid test value (0, must be 1-10)",
      )
    end

    it "returns false when value is above max" do
      expect(validator.send(:check_range, 11, 1, 10, "test value")).to be false
      expect(context.errors.first[:message]).to include(
        "invalid test value (11, must be 1-10)",
      )
    end
  end

  describe "#check_enum" do
    it "returns true when value is in valid list" do
      expect(validator.send(:check_enum, 2, [1, 2, 3], "color type")).to be true
      expect(context.errors).to be_empty
    end

    it "returns false when value is not in valid list" do
      expect(validator.send(:check_enum, 5, [1, 2, 3],
                            "color type")).to be false
      expect(context.errors.first[:message]).to include(
        "invalid color type (5, must be one of 1, 2, 3)",
      )
    end

    it "works with string values" do
      expect(validator.send(:check_enum, "RGB", %w[RGB RGBA],
                            "mode")).to be true
    end
  end

  describe "#check_crc" do
    it "returns true when CRC is valid" do
      allow(chunk).to receive(:crc_valid?).and_return(true)
      expect(validator.send(:check_crc)).to be true
      expect(context.errors).to be_empty
    end

    it "returns false and adds error when CRC is invalid" do
      allow(chunk).to receive(:crc_valid?).and_return(false)
      expect(validator.send(:check_crc)).to be false
      expect(context.errors.size).to eq(1)
      expect(context.errors.first[:message]).to include(
        "CRC error in TEST chunk",
      )
    end
  end
end

RSpec.describe PngConform::Validators::ValidationContext do
  let(:context) { described_class.new }

  describe "#initialize" do
    it "initializes with empty errors" do
      expect(context.errors).to eq([])
    end

    it "initializes with empty chunks_seen" do
      expect(context.chunks_seen).to eq({})
    end

    it "initializes with empty file_info" do
      expect(context.file_info).to eq({})
    end
  end

  describe "#add_error" do
    it "adds error with all attributes" do
      context.add_error(
        chunk_type: "IHDR",
        message: "test error",
        severity: :error,
        offset: 8,
      )

      expect(context.errors.size).to eq(1)
      error = context.errors.first
      expect(error[:chunk_type]).to eq("IHDR")
      expect(error[:message]).to eq("test error")
      expect(error[:severity]).to eq(:error)
      expect(error[:offset]).to eq(8)
    end

    it "adds error with default severity" do
      context.add_error(chunk_type: "PLTE", message: "test")
      expect(context.errors.first[:severity]).to eq(:error)
    end

    it "adds error with nil offset" do
      context.add_error(chunk_type: "IDAT", message: "test", offset: nil)
      expect(context.errors.first[:offset]).to be_nil
    end
  end

  describe "#record_chunk" do
    it "records chunk type" do
      context.record_chunk("IHDR")
      expect(context.seen?("IHDR")).to be true
    end

    it "records chunk type with chunk object" do
      chunk = double("Chunk")
      context.record_chunk("IDAT", chunk)
      expect(context.chunks_of_type("IDAT")).to eq([chunk])
    end

    it "allows multiple chunks of same type" do
      chunk1 = double("Chunk1")
      chunk2 = double("Chunk2")
      context.record_chunk("IDAT", chunk1)
      context.record_chunk("IDAT", chunk2)
      expect(context.chunks_of_type("IDAT")).to eq([chunk1, chunk2])
    end
  end

  describe "#mark_chunk_seen" do
    it "is an alias for record_chunk" do
      context.mark_chunk_seen("TEST")
      expect(context.seen?("TEST")).to be true
    end
  end

  describe "#seen?" do
    it "returns true for seen chunk types" do
      context.record_chunk("IHDR")
      expect(context.seen?("IHDR")).to be true
    end

    it "returns false for unseen chunk types" do
      expect(context.seen?("PLTE")).to be false
    end
  end

  describe "#chunks_of_type" do
    it "returns empty array for unseen chunk type" do
      expect(context.chunks_of_type("UNKNOWN")).to eq([])
    end

    it "returns recorded chunks" do
      chunk1 = double("Chunk1")
      chunk2 = double("Chunk2")
      context.record_chunk("TEXT", chunk1)
      context.record_chunk("TEXT", chunk2)
      expect(context.chunks_of_type("TEXT")).to eq([chunk1, chunk2])
    end
  end

  describe "#store and #retrieve" do
    it "stores and retrieves values" do
      context.store(:width, 640)
      expect(context.retrieve(:width)).to eq(640)
    end

    it "returns nil for unset keys" do
      expect(context.retrieve(:height)).to be_nil
    end

    it "overwrites existing values" do
      context.store(:depth, 8)
      context.store(:depth, 16)
      expect(context.retrieve(:depth)).to eq(16)
    end
  end

  describe "#has_errors?" do
    it "returns false when no errors" do
      expect(context.has_errors?).to be false
    end

    it "returns true when errors exist" do
      context.add_error(chunk_type: "TEST", message: "error", severity: :error)
      expect(context.has_errors?).to be true
    end

    it "returns false when only warnings exist" do
      context.add_error(chunk_type: "TEST", message: "warning",
                        severity: :warning)
      expect(context.has_errors?).to be false
    end
  end

  describe "#has_warnings?" do
    it "returns false when no warnings" do
      expect(context.has_warnings?).to be false
    end

    it "returns true when warnings exist" do
      context.add_error(chunk_type: "TEST", message: "warning",
                        severity: :warning)
      expect(context.has_warnings?).to be true
    end

    it "returns false when only errors exist" do
      context.add_error(chunk_type: "TEST", message: "error", severity: :error)
      expect(context.has_warnings?).to be false
    end
  end

  describe "#all_errors" do
    it "returns only errors" do
      context.add_error(chunk_type: "T1", message: "error", severity: :error)
      context.add_error(chunk_type: "T2", message: "warning",
                        severity: :warning)
      context.add_error(chunk_type: "T3", message: "info", severity: :info)

      errors = context.all_errors
      expect(errors.size).to eq(1)
      expect(errors.first[:severity]).to eq(:error)
    end
  end

  describe "#all_warnings" do
    it "returns only warnings" do
      context.add_error(chunk_type: "T1", message: "error", severity: :error)
      context.add_error(chunk_type: "T2", message: "warning",
                        severity: :warning)
      context.add_error(chunk_type: "T3", message: "info", severity: :info)

      warnings = context.all_warnings
      expect(warnings.size).to eq(1)
      expect(warnings.first[:severity]).to eq(:warning)
    end
  end

  describe "#all_info" do
    it "returns only info messages" do
      context.add_error(chunk_type: "T1", message: "error", severity: :error)
      context.add_error(chunk_type: "T2", message: "warning",
                        severity: :warning)
      context.add_error(chunk_type: "T3", message: "info", severity: :info)

      info = context.all_info
      expect(info.size).to eq(1)
      expect(info.first[:severity]).to eq(:info)
    end
  end

  describe "attribute-style access" do
    it "allows setter syntax" do
      context.width = 800
      expect(context.retrieve(:width)).to eq(800)
    end

    it "allows getter syntax" do
      context.store(:height, 600)
      expect(context.height).to eq(600)
    end

    it "works with chaining" do
      context.width = 1024
      context.height = 768
      expect(context.width).to eq(1024)
      expect(context.height).to eq(768)
    end

    it "responds to any method" do
      # ValidationContext responds to any method via method_missing
      expect(context).to respond_to(:any_method)
    end
  end
end
