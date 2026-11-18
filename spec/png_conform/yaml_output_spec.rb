# frozen_string_literal: true

require "spec_helper"
require "png_conform/analyzers/metrics_analyzer"
require "png_conform/commands/check_command"
require "png_conform/reporters/yaml_reporter"

RSpec.describe "YAML output through YamlIO" do
  let(:result) do
    PngConform::Models::ValidationResult.new(
      filename: "test.png", file_type: "PNG", file_size: 0,
    )
  end
  let(:analyzer) { PngConform::Analyzers::MetricsAnalyzer.new(result) }
  let(:long_value) { "#{'long value ' * 30}test.png" }
  let(:metrics) { analyzer.analyze.merge("description" => long_value) }
  let(:analysis) do
    PngConform::Models::FileAnalysis.new(
      file_path: long_value, file_type: "PNG", file_size: 0,
      validation_result: result, metrics: metrics
    )
  end

  before do
    allow(PngConform::YamlIO).to receive(:dump).and_call_original
  end

  it "serializes analyzer metrics without using Hash#to_yaml" do
    allow(analyzer).to receive(:analyze).and_return(metrics)
    allow(metrics).to receive(:to_yaml).and_raise("must use YamlIO.dump")

    expect(YAML.safe_load(analyzer.to_yaml, permitted_classes: [Symbol]))
      .to eq(metrics)
    expect(PngConform::YamlIO).to have_received(:dump).with(metrics)
  end

  it "serializes reports through the wrapper" do
    output = StringIO.new

    PngConform::Reporters::YamlReporter.new(output).report(analysis)

    expect(YAML.safe_load(output.string, permitted_classes: [Symbol]))
      .to eq(analysis.to_h)
    expect(PngConform::YamlIO).to have_received(:dump).with(analysis.to_h)
  end

  it "prints YAML metrics through the wrapper" do
    command = PngConform::Commands::CheckCommand.new([], format: "yaml")
    allow(analysis).to receive(:metrics).and_return(metrics)
    allow(metrics).to receive(:to_yaml).and_raise("must use YamlIO.dump")
    output = StringIO.new

    allow(command).to receive(:puts) { |yaml| output.puts(yaml) }
    command.send(:show_metrics, analysis)

    expect(YAML.safe_load(output.string, permitted_classes: [Symbol]))
      .to eq(metrics)
    expect(PngConform::YamlIO).to have_received(:dump).with(metrics).once
  end
end
