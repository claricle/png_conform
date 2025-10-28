# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::ValidationError do
  describe "constants" do
    it "defines severity levels" do
      expect(described_class::SEVERITY_ERROR).to eq("error")
      expect(described_class::SEVERITY_WARNING).to eq("warning")
      expect(described_class::SEVERITY_INFO).to eq("info")
    end

    it "defines error types" do
      expect(described_class::ERROR_TYPE_SIGNATURE).to eq("signature")
      expect(described_class::ERROR_TYPE_CRC).to eq("crc")
      expect(described_class::ERROR_TYPE_CHUNK_ORDER).to eq("chunk_order")
      expect(described_class::ERROR_TYPE_CHUNK_DATA).to eq("chunk_data")
      expect(described_class::ERROR_TYPE_ZLIB).to eq("zlib")
      expect(described_class::ERROR_TYPE_MISSING_CHUNK).to eq("missing_chunk")
      expect(described_class::ERROR_TYPE_INVALID_VALUE).to eq("invalid_value")
      expect(described_class::ERROR_TYPE_PROFILE).to eq("profile")
    end
  end

  describe ".error" do
    it "creates an error-level validation error" do
      error = described_class.error("Invalid CRC")
      expect(error.severity).to eq("error")
      expect(error.message).to eq("Invalid CRC")
    end

    it "accepts optional parameters" do
      error = described_class.error(
        "Invalid CRC",
        chunk_type: "IDAT",
        chunk_offset: 100,
        error_type: "crc",
      )
      expect(error.chunk_type).to eq("IDAT")
      expect(error.chunk_offset).to eq(100)
      expect(error.error_type).to eq("crc")
    end
  end

  describe ".warning" do
    it "creates a warning-level validation error" do
      warning = described_class.warning("Deprecated chunk")
      expect(warning.severity).to eq("warning")
      expect(warning.message).to eq("Deprecated chunk")
    end

    it "accepts optional parameters" do
      warning = described_class.warning(
        "Deprecated chunk",
        chunk_type: "oFFs",
        chunk_offset: 200,
      )
      expect(warning.chunk_type).to eq("oFFs")
      expect(warning.chunk_offset).to eq(200)
    end
  end

  describe ".info" do
    it "creates an info-level validation error" do
      info = described_class.info("Additional info")
      expect(info.severity).to eq("info")
      expect(info.message).to eq("Additional info")
    end

    it "accepts optional parameters" do
      info = described_class.info(
        "Additional info",
        chunk_type: "tEXt",
      )
      expect(info.chunk_type).to eq("tEXt")
    end
  end

  describe "#error?" do
    it "returns true for error severity" do
      error = described_class.new(severity: "error")
      expect(error.error?).to be true
    end

    it "returns false for other severities" do
      warning = described_class.new(severity: "warning")
      info = described_class.new(severity: "info")
      expect(warning.error?).to be false
      expect(info.error?).to be false
    end
  end

  describe "#warning?" do
    it "returns true for warning severity" do
      warning = described_class.new(severity: "warning")
      expect(warning.warning?).to be true
    end

    it "returns false for other severities" do
      error = described_class.new(severity: "error")
      info = described_class.new(severity: "info")
      expect(error.warning?).to be false
      expect(info.warning?).to be false
    end
  end

  describe "#info?" do
    it "returns true for info severity" do
      info = described_class.new(severity: "info")
      expect(info.info?).to be true
    end

    it "returns false for other severities" do
      error = described_class.new(severity: "error")
      warning = described_class.new(severity: "warning")
      expect(error.info?).to be false
      expect(warning.info?).to be false
    end
  end

  describe "#to_s" do
    it "formats error with severity and message" do
      error = described_class.new(
        severity: "error",
        message: "Invalid signature",
      )
      expect(error.to_s).to eq("[ERROR] Invalid signature")
    end

    it "includes chunk type when present" do
      error = described_class.new(
        severity: "error",
        message: "Invalid CRC",
        chunk_type: "IDAT",
      )
      expect(error.to_s).to eq("[ERROR] IDAT Invalid CRC")
    end

    it "includes chunk offset when present" do
      error = described_class.new(
        severity: "error",
        message: "Invalid data",
        chunk_offset: 1024,
      )
      expect(error.to_s).to eq("[ERROR] at 0x00400 Invalid data")
    end

    it "includes both chunk type and offset" do
      error = described_class.new(
        severity: "error",
        message: "Invalid CRC",
        chunk_type: "IDAT",
        chunk_offset: 100,
      )
      expect(error.to_s).to eq("[ERROR] IDAT at 0x00064 Invalid CRC")
    end

    it "uppercases severity level" do
      warning = described_class.new(
        severity: "warning",
        message: "Deprecated",
      )
      info = described_class.new(
        severity: "info",
        message: "Note",
      )
      expect(warning.to_s).to eq("[WARNING] Deprecated")
      expect(info.to_s).to eq("[INFO] Note")
    end
  end

  describe "attribute initialization" do
    it "accepts all attributes" do
      error = described_class.new(
        severity: "error",
        message: "Test error",
        chunk_type: "PLTE",
        chunk_offset: 512,
        error_type: "chunk_data",
        expected: "256 entries",
        actual: "128 entries",
      )

      expect(error.severity).to eq("error")
      expect(error.message).to eq("Test error")
      expect(error.chunk_type).to eq("PLTE")
      expect(error.chunk_offset).to eq(512)
      expect(error.error_type).to eq("chunk_data")
      expect(error.expected).to eq("256 entries")
      expect(error.actual).to eq("128 entries")
    end
  end
end
