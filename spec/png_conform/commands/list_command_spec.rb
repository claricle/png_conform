# frozen_string_literal: true

require "spec_helper"
require "png_conform/commands/list_command"

RSpec.describe PngConform::Commands::ListCommand do
  let(:options) { {} }

  describe "#initialize" do
    it "accepts options" do
      command = described_class.new(options)
      expect(command.options).to eq(options)
    end
  end

  describe "#run" do
    it "returns exit code 0" do
      command = described_class.new(options)
      suppress_output { expect(command.run).to eq(0) }
    end

    it "displays available profiles header" do
      command = described_class.new(options)
      expect do
        command.run
      end.to output(/Available Validation Profiles:/).to_stdout
    end

    it "lists all available profiles" do
      command = described_class.new(options)
      output = capture_output { command.run }

      expect(output).to include("MINIMAL")
      expect(output).to include("WEB")
      expect(output).to include("PRINT")
      expect(output).to include("ARCHIVE")
      expect(output).to include("STRICT")
      expect(output).to include("DEFAULT")
    end

    it "displays profile details" do
      command = described_class.new(options)
      output = capture_output { command.run }

      # Check for required chunks in minimal profile
      expect(output).to include("Required chunks: IHDR, IDAT, IEND")
    end
  end

  def suppress_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original_stdout
  end

  def capture_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
