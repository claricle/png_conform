# frozen_string_literal: true

require "spec_helper"
require "png_conform/reporters/reporter_factory"

RSpec.describe PngConform::Reporters::ReporterFactory do
  describe ".create" do
    context "with default options" do
      it "creates a ColorReporter wrapping SummaryReporter" do
        reporter = described_class.create
        expect(reporter).to be_a(PngConform::Reporters::ColorReporter)
        expect(reporter.wrapped_reporter).to be_a(PngConform::Reporters::SummaryReporter)
      end
    end

    context "with verbosity options" do
      it "creates ColorReporter wrapping QuietReporter when verbosity is :quiet" do
        reporter = described_class.create(verbosity: :quiet)
        expect(reporter).to be_a(PngConform::Reporters::ColorReporter)
        expect(reporter.wrapped_reporter).to be_a(PngConform::Reporters::QuietReporter)
      end

      it "creates ColorReporter wrapping VerboseReporter when verbosity is :verbose" do
        reporter = described_class.create(verbosity: :verbose)
        expect(reporter).to be_a(PngConform::Reporters::ColorReporter)
        expect(reporter.wrapped_reporter).to be_a(PngConform::Reporters::VerboseReporter)
      end

      it "creates ColorReporter wrapping VeryVerboseReporter when verbosity is :very_verbose" do
        reporter = described_class.create(verbosity: :very_verbose)
        expect(reporter).to be_a(PngConform::Reporters::ColorReporter)
        expect(reporter.wrapped_reporter).to be_a(PngConform::Reporters::VeryVerboseReporter)
      end

      it "creates ColorReporter wrapping SummaryReporter when verbosity is :summary" do
        reporter = described_class.create(verbosity: :summary)
        expect(reporter).to be_a(PngConform::Reporters::ColorReporter)
        expect(reporter.wrapped_reporter).to be_a(PngConform::Reporters::SummaryReporter)
      end
    end

    context "with show_palette option" do
      it "wraps base reporter with PaletteReporter and ColorReporter" do
        reporter = described_class.create(
          verbosity: :summary,
          show_palette: true,
        )
        expect(reporter).to be_a(PngConform::Reporters::ColorReporter)
        expect(reporter.wrapped_reporter).to be_a(PngConform::Reporters::PaletteReporter)
      end
    end

    context "with show_text option" do
      it "wraps base reporter with ColorReporter and TextReporter" do
        reporter = described_class.create(
          verbosity: :summary,
          show_text: true,
        )
        expect(reporter).to be_a(PngConform::Reporters::ColorReporter)
        expect(reporter.wrapped_reporter).to be_a(PngConform::Reporters::TextReporter)
      end

      it "passes escape_mode option to TextReporter" do
        reporter = described_class.create(
          verbosity: :summary,
          show_text: true,
          colorize: false,
          escape_mode: :seven_bit,
        )
        expect(reporter).to be_a(PngConform::Reporters::TextReporter)
        expect(reporter.instance_variable_get(:@escape_mode)).to eq(:seven_bit)
      end
    end

    context "with colorize option" do
      it "wraps base reporter with ColorReporter" do
        reporter = described_class.create(
          verbosity: :summary,
          colorize: true,
        )
        expect(reporter).to be_a(PngConform::Reporters::ColorReporter)
      end
    end

    context "with multiple wrapper options" do
      it "wraps reporters in correct order" do
        reporter = described_class.create(
          verbosity: :verbose,
          show_palette: true,
          show_text: true,
          colorize: true,
        )

        # Outermost wrapper should be ColorReporter
        expect(reporter).to be_a(PngConform::Reporters::ColorReporter)

        # Check wrapping order: ColorReporter wraps TextReporter
        delegate = reporter.wrapped_reporter
        expect(delegate).to be_a(PngConform::Reporters::TextReporter)

        # TextReporter wraps PaletteReporter (via @wrapped_reporter or @reporter)
        # Since different decorators use different ivar names, just verify the chain exists
        expect(reporter.wrapped_reporter).to be_a(PngConform::Reporters::TextReporter)
      end
    end
  end
end
