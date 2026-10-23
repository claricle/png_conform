# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "PngConform shared diagnostic contract" do
  subject(:error) do
    PngConform::Models::ValidationError.error(
      "Bad CRC",
      chunk_type: "IDAT", chunk_offset: 33, chunk_index: 2, field: "crc",
      error_type: "crc", requirement_id: "png.chunk.crc",
      expected: "0xAB", actual: "0xCD", remediation: "Rewrite the CRC",
      citation_uri: "https://www.w3.org/TR/png/#5CRC-algorithm",
      citation_label: "PNG CRC"
    )
  end

  let(:wire) { JSON.parse(JSON.generate(error.to_lens_h)) }

  it "uses the LensCore schema version 1 without a local copy" do
    expect(LensCore::SCHEMA_VERSION).to eq(1)
    source = Object.const_source_location(:LensCore).first
    expect(source).not_to start_with(File.expand_path("../../../lib", __dir__))
  end

  it "round-trips identity, kind, severity, message, citation and location" do
    expect(wire).to include(
      "severity" => "error", "kind" => "crc",
      "requirement_id" => "png.chunk.crc", "message" => "Bad CRC",
      "citations" => [{ "uri" => "https://www.w3.org/TR/png/#5CRC-algorithm",
                        "label" => "PNG CRC" }],
      "location" => { "type" => "binary", "byte_offset" => 33,
                      "record_index" => 2, "record_type" => "IDAT",
                      "field" => "crc" }
    )
    expect(LensCore::Diagnostic.from_h(wire)).to eq(error.to_diagnostic)
  end

  it "uses only JSON-safe primitives and stable serialization" do
    expect(JSON.generate(error.to_lens_h)).to eq(
      '{"severity":"error","kind":"crc","requirement_id":"png.chunk.crc",' \
      '"message":"Bad CRC","citations":[{"uri":' \
      '"https://www.w3.org/TR/png/#5CRC-algorithm","label":"PNG CRC"}],' \
      '"remediation":"Rewrite the CRC","context":{"actual":"0xCD",' \
      '"expected":"0xAB"},"location":{"type":"binary","byte_offset":33,' \
      '"record_index":2,"record_type":"IDAT","field":"crc"}}',
    )
    expect(wire.fetch("context")).to eq("expected" => "0xAB",
                                        "actual" => "0xCD")
  end

  it "omits unknown optional fields instead of placeholders" do
    bare = PngConform::Models::ValidationError.warning("odd").to_lens_h
    expect(bare.keys).to eq(%w[severity kind requirement_id message citations
                               context])
    expect(bare).to include("kind" => "validation",
                            "requirement_id" => "png.unspecified")
  end

  it "projects the location through the binary type with a field extension" do
    location = PngConform::Diagnostics::Location.new(byte_offset: 0)
    expect(location.to_lens.to_h).to eq("type" => "binary", "byte_offset" => 0)
    expect(location).to be_frozen
  end

  describe "human rendering" do
    it "renders the same diagnostic" do
      text = error.to_human
      expect(text).to include("error  png.chunk.crc  (crc)",
                              "at byte offset 33, record 2, IDAT",
                              "Bad CRC", "fix: Rewrite the CRC",
                              "see: PNG CRC https://www.w3.org/TR/png/")
    end

    it "changes both representations when a structured field changes" do
      other = error.dup.tap { |e| e.chunk_offset = 99 }
      expect(other.to_lens_h.dig("location", "byte_offset")).to eq(99)
      expect(other.to_human).to include("byte offset 99")
      expect(other.to_human).not_to include("byte offset 33")
    end
  end
end
