# frozen_string_literal: true

require "spec_helper"
require "png_conform/commands/check_command"
require "tempfile"

RSpec.describe PngConform::Commands::CheckCommand do
  let(:valid_png_path) do
    "spec/fixtures/pngsuite/basic/non_interlaced/basn0g01.png"
  end
  let(:options) { {} }

  describe "#initialize" do
    it "accepts files and options" do
      command = described_class.new([valid_png_path], options)
      expect(command.files).to eq([valid_png_path])
      expect(command.options).to eq(options)
    end
  end

  describe "#run" do
    context "with no files" do
      it "displays error and exits" do
        command = described_class.new([], options)
        expect { command.run }.to output(/No files specified/).to_stdout
          .and raise_error(PngConform::NoFilesSpecifiedError)
      end
    end

    context "with non-existent file" do
      it "displays error message" do
        command = described_class.new(["nonexistent.png"], options)
        expect { command.run }.to output(/File not found/).to_stdout
      end

      it "returns error exit code" do
        command = described_class.new(["nonexistent.png"], options)
        suppress_output { expect(command.run).to eq(1) }
      end
    end

    context "with invalid profile" do
      let(:options) { { profile: "invalid_profile" } }

      it "displays error about unknown profile" do
        command = described_class.new([valid_png_path], options)
        expect { command.run }.to output(/Unknown profile/).to_stdout
          .and raise_error(PngConform::UnknownProfileError)
      end
    end

    context "with conflicting options" do
      let(:options) { { quiet: true, verbose: true } }

      it "warns about conflicting options" do
        command = described_class.new([valid_png_path], options)
        expect { command.run }.to output(/mutually exclusive/).to_stdout
      end
    end
  end

  def suppress_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original_stdout
  end
end
