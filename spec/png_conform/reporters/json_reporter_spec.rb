# frozen_string_literal: true

RSpec.describe PngConform::Reporters::JsonReporter do
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
    it "outputs JSON format" do
      reporter.report(result)
      output.rewind
      json_output = output.read

      expect(json_output).to include('"filename": "test.png"')
      expect(json_output).to include('"file_type": "PNG"')
      expect(json_output).to include('"file_size": 1000')
    end

    it "includes CRC error count" do
      result.crc_errors_count = 2
      reporter.report(result)
      output.rewind
      json_output = output.read

      expect(json_output).to include('"crc_errors_count": 2')
    end

    it "produces valid JSON" do
      reporter.report(result)
      output.rewind
      json_output = output.read

      expect { JSON.parse(json_output) }.not_to raise_error
    end

    it "pretty-prints JSON" do
      reporter.report(result)
      output.rewind
      json_output = output.read

      # Pretty-printed JSON has newlines and indentation
      expect(json_output).to include("\n")
      expect(json_output.lines.count).to be > 1
    end
  end
end
