# frozen_string_literal: true

require "png_conform/reporters/yaml_reporter"

RSpec.describe PngConform::Reporters::YamlReporter do
  let(:output) { StringIO.new }
  let(:reporter) { described_class.new(output) }

  let(:validation_result) do
    PngConform::Models::ValidationResult.new.tap do |r|
      r.filename = "test.png"
      r.file_type = "PNG"
      r.file_size = 1000
      r.crc_errors_count = 0
      r.valid = true
    end
  end

  let(:file_analysis) do
    PngConform::Models::FileAnalysis.new.tap do |fa|
      fa.file_path = "test.png"
      fa.file_size = 1000
      fa.file_type = "PNG"
      fa.validation_result = validation_result
    end
  end

  describe "#report" do
    it "outputs YAML format" do
      reporter.report(file_analysis)
      output.rewind
      yaml_output = output.read

      expect(yaml_output).to start_with("---")
      expect(yaml_output).to include("filename: test.png")
      expect(yaml_output).to include("file_type: PNG")
      expect(yaml_output).to include("file_size: 1000")
    end

    it "includes CRC error count" do
      validation_result.crc_errors_count = 2
      reporter.report(file_analysis)
      output.rewind
      yaml_output = output.read

      expect(yaml_output).to include("crc_errors_count: 2")
    end

    it "produces valid YAML" do
      reporter.report(file_analysis)
      output.rewind
      yaml_output = output.read

      expect do
        YAML.safe_load(yaml_output, permitted_classes: [Symbol])
      end.not_to raise_error
    end
  end

  describe "structured diagnostics" do
    it "serializes the same diagnostics and version as JSON" do
      validation_result.error("bad", chunk_type: "IHDR", chunk_offset: 8,
                                     error_type: "value")
      reporter.report(file_analysis)
      output.rewind
      parsed = YAML.safe_load(output.read)

      expect(parsed["schema_version"]).to eq(LensCore::SCHEMA_VERSION)
      expect(parsed["diagnostics"])
        .to eq(JSON.parse(JSON.generate(file_analysis.to_h))["diagnostics"])
    end
  end
end
