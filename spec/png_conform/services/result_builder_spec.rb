# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Services::ResultBuilder do
  let(:context) { PngConform::Validators::ValidationContext.new }
  let(:reader) { double("reader", file_size: 8) }
  let(:analysis) { described_class.new(reader, "x.png", context, []).build }
  let(:errors) { analysis.validation_result.errors }

  before do
    context.add_diagnostic(
      "png.IHDR.bit-depth", "invalid bit depth (3)",
      chunk_type: "IHDR", offset: 8, chunk_index: 0, field: "bit depth",
      expected: "1, 2, 4, 8, 16", actual: 3
    )
    context.add_diagnostic("png.IHDR.width-recommended-max", "wide",
                           chunk_type: "IHDR", offset: 8)
    context.add_diagnostic("info.png.PLTE.palette-present", "palette",
                           chunk_type: "PLTE", offset: 33)
  end

  it "appends each context diagnostic itself, not a message-only copy" do
    expect(errors).to eq(context.all_errors + context.all_warnings +
                         context.all_info)
    expect(errors.first).to equal(context.all_errors.first)
  end

  it "preserves identity, severity, location, citation and context exactly" do
    expect(errors.first.to_lens_h).to include(
      "severity" => "error", "kind" => "value",
      "requirement_id" => "png.IHDR.bit-depth",
      "message" => "invalid bit depth (3)",
      "context" => { "expected" => "1, 2, 4, 8, 16", "actual" => "3" },
      "location" => { "type" => "binary", "byte_offset" => 8,
                      "record_index" => 0, "record_type" => "IHDR",
                      "field" => "bit depth" }
    )
    expect(errors.first.to_lens_h["citations"].first["label"])
      .to include("11.2.2")
  end

  it "keeps severities and marks the result invalid only for errors" do
    expect(errors.map(&:severity)).to eq(%w[error warning info])
    expect(analysis.validation_result.valid).to be false
    expect(analysis.validation_result.error_count).to eq(1)
    expect(analysis.validation_result.warning_count).to eq(1)
    expect(analysis.validation_result.info_count).to eq(1)
  end
end
