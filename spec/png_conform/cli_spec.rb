# frozen_string_literal: true

require "spec_helper"
require "png_conform/cli"

RSpec.describe PngConform::Cli do
  describe "check diagnostic locations" do
    batch_flags = [[], ["--no-batch"]]
    %w[json yaml].each do |format|
      batch_flags.each do |flags|
        it "preserves chunk offsets in #{format} with flags #{flags.inspect}" do
          path = "spec/fixtures/pngsuite/corrupted/xhdn0g08.png"
          expected = JSON.parse(File.read("spec/fixtures/diagnostics/pngsuite/corrupted/xhdn0g08.png.json"))

          expect do
            described_class.start(["check", "-f", format, *flags, path])
          end.to output(satisfy do |output|
            report = format == "json" ? JSON.parse(output) : YAML.safe_load(output, permitted_classes: [Symbol])
            expect(report.fetch("diagnostics"))
              .to eq(expected.fetch("diagnostics"))
          end).to_stdout
        end
      end
    end
  end

  describe "version command" do
    it "displays version information" do
      expect { described_class.start(["version"]) }.to output(
        /png_conform version #{PngConform::VERSION}/o,
      ).to_stdout
    end

    it "displays Ruby version" do
      expect { described_class.start(["version"]) }.to output(
        /Ruby version #{RUBY_VERSION}/o,
      ).to_stdout
    end
  end

  describe "help command" do
    it "displays help when no arguments given" do
      expect { described_class.start([]) }.to output(/Commands:/).to_stdout
    end

    it "displays help with help command" do
      expect do
        described_class.start(["help"])
      end.to output(/Commands:/).to_stdout
    end

    it "displays help for check command" do
      expect { described_class.start(%w[help check]) }.to output(
        /Usage:.*check/m,
      ).to_stdout
    end
  end

  describe "unknown command" do
    it "displays error for unknown command" do
      expect do
        described_class.start(["unknown"])
      rescue SystemExit
        # Thor raises SystemExit on unknown commands
      end.to output(/Could not find command/).to_stderr
    end
  end
end
