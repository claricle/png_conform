# frozen_string_literal: true

require "spec_helper"
require "json"
require "png_conform/reporters/json_reporter"
require_relative "../support/documented_report_example"

RSpec.describe "documented structured report example" do
  let(:doc) { File.read(File.expand_path("../../docs/CLI_OPTIONS.adoc", __dir__)) }
  let(:documented) do
    block = doc[/\/\/ structured-json-example\n\[source,json\]\n----\n(.*?)\n----/m, 1]
    JSON.parse(block)
  end

  it "matches the JSON the reporter emits" do
    output = StringIO.new
    PngConform::Reporters::JsonReporter.new(output)
      .report(DocumentedReportExample.analysis)

    expect(documented).to eq(JSON.parse(output.string))
  end

  it "states the schema version the report carries" do
    expect(documented["schema_version"]).to eq(LensCore::SCHEMA_VERSION)
  end

  it "names every compatibility alias" do
    %w[severity message chunk_type chunk_offset error_type expected actual]
      .each { |alias_name| expect(doc).to include("`#{alias_name}`") }
  end
end
