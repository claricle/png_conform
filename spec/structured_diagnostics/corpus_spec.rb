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
  # Independent expectations for the invalid cases described in fixtures.yml.
  # Keep these separate from the validator's citation registry so regeneration
  # cannot silently bless a missing or incorrect format-specific citation.
  citation_cases = [
    ["mng/invalid-missing-mend.mng", "mng.MEND.missing", "mng", "4.1.2"],
    ["mng/invalid-mhdr-not-first.mng", "mng.MHDR.first-chunk", "mng", "4.1.1"],
    ["mng/invalid-zero-dimensions.mng", "mng.MHDR.frame-dimensions-zero", "mng", "4.1.1"],
    ["mng/invalid-bad-crc.mng", "mng.MHDR.crc", "png", "5.5"],
    ["jng/invalid-missing-jdat.jng", "jng.JDAT.missing", "jng", "1.1.2"],
    ["jng/invalid-missing-iend.jng", "jng.IEND.missing", "jng", "1.1.6"],
    ["jng/invalid-compression-method.jng", "jng.JHDR.image-compression-method", "jng", "1.1.1"],
    ["jng/invalid-color-type.jng", "jng.JHDR.color-type", "jng", "1.1.1"],
  ]
  citation_uris = {
    "mng" => "http://www.libpng.org/pub/mng/spec/",
    "jng" => "http://www.libpng.org/pub/mng/spec/jng.html",
    "png" => "https://www.w3.org/TR/2003/REC-PNG-20031110/",
  }

  citation_cases.each do |file, requirement, format, section|
    it "cites the expected specification section for #{file}" do
      report = JSON.parse(File.read("#{goldens}/#{file}.json"))

      expect(report.fetch("diagnostics")).to include(
        include("requirement_id" => requirement,
                "citations" => include(
                  include("uri" => citation_uris.fetch(format),
                          "label" => include("section #{section}:")),
                )),
      )
    end
  end
  # rubocop:enable RSpec/LeakyLocalVariable
end
