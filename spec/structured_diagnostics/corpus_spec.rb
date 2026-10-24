# frozen_string_literal: true

require "spec_helper"
require "json"
require "yaml"

RSpec.describe "Structured diagnostics corpus" do
  # rubocop:disable RSpec/LeakyLocalVariable -- data-driven corpus examples
  root = File.expand_path("../..", __dir__)
  fixtures = File.join(root, "spec/fixtures")
  goldens = File.join(fixtures, "diagnostics")
  extensions = %w[.png .mng .jng].freeze
  inputs = Dir.glob("#{fixtures}/**/*").select do |path|
    File.file?(path) && extensions.include?(File.extname(path).downcase) &&
      !path.start_with?("#{goldens}/")
  end.sort
  golden_files = Dir.glob("#{goldens}/**/*").select { |path| File.file?(path) }

  it "has exactly one golden per input, with no orphan goldens" do
    expect(inputs).not_to be_empty
    expected = inputs.map do |path|
      "#{goldens}/#{path.delete_prefix("#{fixtures}/")}.json"
    end
    expect(golden_files).to match_array(expected)
  end

  inputs.each do |input|
    relative = input.delete_prefix("#{root}/")
    golden = "#{goldens}/#{input.delete_prefix("#{fixtures}/")}.json"

    it "matches the complete report for #{relative}", :aggregate_failures do
      report = JSON.parse(File.read(golden))
      result = PngConform::Services::ValidationService.validate_file(input)
        .validation_result

      expect(report.fetch("schema_version")).to eq(LensCore::SCHEMA_VERSION)
      expect(report).to eq(result.to_lens_report(filename: relative).to_h)
    end
  end

  it "includes valid reports and preserves their absence of errors" do
    reports = golden_files.map { |path| JSON.parse(File.read(path)) }
    valid_reports = reports.select { |report| report.fetch("valid") }

    expect(valid_reports).not_to be_empty
    diagnostics = valid_reports.flat_map { |report| report.fetch("diagnostics") }
    expect(diagnostics).not_to include(include("severity" => "error"))
  end

  %w[mng jng].each do |format|
    metadata = YAML.safe_load_file("#{fixtures}/#{format}/fixtures.yml")
    metadata.fetch("fixtures").each do |entry|
      it "preserves expected validity for #{format}/#{entry.fetch('file')}" do
        report = JSON.parse(File.read(
                              "#{goldens}/#{format}/#{entry.fetch('file')}.json",
                            ))
        expect(report.fetch("valid"))
          .to eq(entry.fetch("expected_validity") == "valid")
      end
    end
  end
  # rubocop:enable RSpec/LeakyLocalVariable
end
