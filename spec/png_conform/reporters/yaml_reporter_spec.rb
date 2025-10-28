# frozen_string_literal: true

RSpec.describe PngConform::Reporters::YamlReporter do
  let(:output) { StringIO.new }
  let(:reporter) { described_class.new(output) }
  let(:result) { PngConform::Models::ValidationResult.new }

  before do
    result.filename = "test.png"
    result.file_type = "PNG"
    result.file_size = 1000
    result.crc_errors_count = 0
  end

  describe "#report" do
    it "outputs YAML format" do
      reporter.report(result)
      output.rewind
      yaml_output = output.read

      expect(yaml_output).to start_with("---")
      expect(yaml_output).to include("filename: test.png")
      expect(yaml_output).to include("file_type: PNG")
      expect(yaml_output).to include("file_size: 1000")
    end

    it "includes CRC error count" do
      result.crc_errors_count = 2
      reporter.report(result)
      output.rewind
      yaml_output = output.read

      expect(yaml_output).to include("crc_errors_count: 2")
    end

    it "produces valid YAML" do
      reporter.report(result)
      output.rewind
      yaml_output = output.read

      expect do
        YAML.safe_load(yaml_output, permitted_classes: [Symbol])
      end.not_to raise_error
    end
  end
end
