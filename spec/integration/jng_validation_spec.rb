# frozen_string_literal: true

require "spec_helper"
require_relative "../support/format_file_builder"

RSpec.describe "JNG Validation Integration" do
  let(:builder) { PngConform::Spec::FormatFileBuilder }
  let(:fixture_dir) { File.join(__dir__, "../fixtures/jng") }

  def analyze(bytes, &block)
    builder.with_file(bytes, ".jng") do |path|
      result = PngConform::Services::ValidationService.validate_file(path).validation_result
      yield(result)
    end
  end

  def ids(result) = result.errors.map(&:requirement_id)

  it "accepts a minimal JHDR/JDAT/IEND stream with no diagnostics" do
    analyze(builder.valid_jng) do |result|
      expect(result.errors).to be_empty
      expect(result.file_type).to eq("JNG")
      expect(result).to be_valid
    end
  end

  it "reports a missing JDAT without PNG findings" do
    analyze(builder.jng(builder.jhdr, builder.iend)) do |result|
      expect(ids(result)).to eq(["jng.JDAT.missing"])
      expect(result.errors.first).to have_attributes(chunk_type: "JDAT", severity: "error")
    end
  end

  it "reports a missing IEND without PNG findings" do
    analyze(builder.jng(builder.jhdr, builder.jdat)) do |result|
      expect(ids(result)).to eq(["jng.IEND.missing"])
    end
  end

  it "reports a missing JHDR without PNG findings" do
    analyze(builder.jng(builder.jdat, builder.iend)) do |result|
      expect(ids(result)).to include("jng.JHDR.missing")
      expect(ids(result).grep(/\Apng\./)).to be_empty
    end
  end

  it "reports a misplaced IEND at its location" do
    analyze(builder.jng(builder.jhdr, builder.iend, builder.jdat)) do |result|
      finding = result.errors.find { |e| e.requirement_id == "jng.IEND.last-chunk" }
      expect(finding).to have_attributes(chunk_type: "IEND", chunk_index: 1)
      expect(finding.chunk_offset).to eq(8 + builder.jhdr.bytesize)
    end
  end

  it "reports a misplaced JHDR once" do
    analyze(builder.jng(builder.jdat, builder.jhdr, builder.iend)) do |result|
      expect(ids(result).count("jng.JHDR.first-chunk")).to eq(1)
    end
  end

  it "validates every checked-in JNG fixture to its declared validity" do
    fixtures = YAML.safe_load_file(File.join(fixture_dir, "fixtures.yml"))["fixtures"]
    fixtures.each do |fixture|
      result = PngConform::Services::ValidationService
        .validate_file(File.join(fixture_dir, fixture["file"])).validation_result
      expect(result.valid?).to eq(fixture["expected_validity"] == "valid"), fixture["file"]
      expect(result.file_type).to eq("JNG")
    end
  end
end
