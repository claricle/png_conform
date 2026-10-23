# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/emitter_inventory"

# Every active conformance emitter must construct its finding from a catalog
# ID. This spec enumerates all 47 registered validators and the direct
# service emitters so a new message-only finding fails here.
RSpec.describe "Diagnostic emitter coverage" do
  let(:inventory) { PngConform::Spec::EmitterInventory }
  let(:catalog) { PngConform::Diagnostics::Catalog.default }
  let(:validator_files) { inventory.registered_validator_files }
  # Card 03b converts these; it empties this list when it lands.
  let(:pending_files) { inventory.mng_jng_validator_files }
  let(:converted_files) do
    validator_files - pending_files + inventory::SERVICE_FILES
  end
  let(:sites) do
    converted_files.flat_map do |file|
      inventory.scan(file, **inventory.sources.fetch(file))
    end
  end

  # The catalog ID a site passes: a leading string literal, or id: "...".
  def site_id(call)
    call[/\bid:\s*"([^"]+)"/, 1] || call[/\A\w+\(\s*"([^"]+)"/, 1]
  end

  def claimant(site)
    catalog.find do |req|
      req.emitters.any? { |e| e.file == site.file && e.call == site.call }
    end
  end

  it "enumerates all 47 registered validators: 28 PNG/APNG and 19 MNG/JNG" do
    expect(validator_files.size).to eq(47)
    expect(inventory.png_apng_validator_files.size).to eq(28)
    expect(inventory.mng_jng_validator_files.size).to eq(19)
    expect(validator_files.uniq).to eq(validator_files)
  end

  it "scans a site in every converted PNG/APNG validator" do
    scanned = sites.map(&:file).uniq
    expect(inventory.png_apng_validator_files - scanned).to be_empty
    expect(sites.size).to be > 250
  end

  it "passes a known catalog ID at every converted emitter" do
    missing = sites.reject { |s| catalog.key?(site_id(s.call)) }
    expect(missing.map { |s| [s.file, s.line, s.call] }).to be_empty
  end

  it "makes the cataloged emitter entry the one that carries the ID" do
    mismatched = sites.reject { |s| claimant(s)&.id == site_id(s.call) }
    expect(mismatched.map { |s| [s.file, s.line, s.call] }).to be_empty
  end

  it "reports every site through the method that matches its catalog severity" do
    by_method = { "add_error" => "error", "add_warning" => "warning",
                  "add_info" => "info", "error_result" => "error",
                  "warning_result" => "warning", "success_result" => "info",
                  "check_length" => "error", "check_range" => "error",
                  "check_enum" => "error", "check_crc" => "error" }
    wrong = sites.filter_map do |s|
      want = by_method[s.call[/\A\w+/]]
      severity = catalog.fetch(site_id(s.call)).severity
      [s.file, s.line, s.call] if want && want != severity
    end
    expect(wrong).to be_empty
  end

  it "keeps converted validators off the uncataloged context path" do
    offenders = converted_files.grep(%r{validators/}).select do |file|
      File.read(File.join(inventory::LIB_ROOT, file))
        .match?(/context\.add_error|errors\s*<<|ValidationError\.(error|warning|info)/)
    end
    expect(offenders).to be_empty
  end

  it "removes the transitional message-only path once card 03b converts MNG/JNG" do
    skip "MNG/JNG validators are still pending card 03b" unless pending_files.empty?

    expect(PngConform::Validators::BaseValidator.private_instance_methods)
      .not_to include(:report_message_only)
  end

  it "rejects an uncataloged ID when a diagnostic is built" do
    context = PngConform::Validators::ValidationContext.new
    expect { context.add_diagnostic("png.nope.nope", "x") }
      .to raise_error(PngConform::Diagnostics::Catalog::UnknownIdError)
  end
end
