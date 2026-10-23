# frozen_string_literal: true

require "spec_helper"
require_relative "../support/format_file_builder"

RSpec.describe "MNG Validation Integration" do
  let(:builder) { PngConform::Spec::FormatFileBuilder }
  let(:fixture_dir) { File.join(__dir__, "../fixtures/mng") }

  def analyze(bytes, &block)
    builder.with_file(bytes, ".mng") do |path|
      result = PngConform::Services::ValidationService.validate_file(path).validation_result
      yield(result)
    end
  end

  def ids(result) = result.errors.map(&:requirement_id)

  it "accepts a minimal MHDR/MEND stream with no diagnostics" do
    analyze(builder.valid_mng) do |result|
      expect(result.errors).to be_empty
      expect(result.file_type).to eq("MNG")
      expect(result).to be_valid
    end
  end

  it "accepts an embedded PNG followed by MEND" do
    analyze(builder.mng(builder.mhdr, builder.ihdr, builder.idat, builder.iend, builder.mend)) do |result|
      expect(result.errors).to be_empty
    end
  end

  it "reports a missing MEND without PNG findings" do
    analyze(builder.mng(builder.mhdr)) do |result|
      expect(ids(result)).to eq(["mng.MEND.missing"])
      expect(result.errors.first).to have_attributes(chunk_type: "MEND", severity: "error")
    end
  end

  it "reports a missing MHDR without PNG findings" do
    analyze(builder.mng(builder.mend)) do |result|
      expect(ids(result)).to include("mng.MHDR.missing")
      expect(ids(result).grep(/\Apng\./)).to be_empty
    end
  end

  it "reports a misplaced MEND at its location" do
    analyze(builder.mng(builder.mhdr, builder.mend, builder.chunk("TERM", "\x03".b + ("\x00".b * 9)))) do |result|
      finding = result.errors.find { |e| e.requirement_id == "mng.MEND.last-chunk" }
      expect(finding).to have_attributes(chunk_type: "MEND", chunk_index: 1)
      expect(finding.chunk_offset).to eq(8 + builder.mhdr.bytesize)
    end
  end

  it "reports a misplaced MHDR once" do
    analyze(builder.mng(builder.chunk("TERM", "\x03".b + ("\x00".b * 9)), builder.mhdr, builder.mend)) do |result|
      expect(ids(result).count("mng.MHDR.first-chunk")).to eq(1)
    end
  end

  it "validates every checked-in MNG fixture to its declared validity" do
    fixtures = YAML.safe_load_file(File.join(fixture_dir, "fixtures.yml"))["fixtures"]
    fixtures.each do |fixture|
      result = PngConform::Services::ValidationService
        .validate_file(File.join(fixture_dir, fixture["file"])).validation_result
      expect(result.valid?).to eq(fixture["expected_validity"] == "valid"), fixture["file"]
      expect(result.file_type).to eq("MNG")
    end
  end
end
