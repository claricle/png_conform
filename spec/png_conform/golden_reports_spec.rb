# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "stringio"
require "png_conform/reporters/yaml_reporter"
require "png_conform/reporters/json_reporter"

RSpec.describe "golden reporter bytes" do
  let(:root) { File.expand_path("../..", __dir__) }

  extensions = %w[.png .mng .jng]
  # rubocop:disable-next RSpec/LeakyLocalVariable -- shared corpus generation and inventory
  fixtures = Dir.glob("spec/fixtures/**/*",
                      base: File.expand_path("../..", __dir__)).select do |path|
    File.file?(File.expand_path("../../#{path}", __dir__)) &&
      extensions.include?(File.extname(path).downcase)
  end.sort

  it "has fixtures and no orphan YAML or JSON goldens" do
    expect(fixtures).not_to be_empty
    formats = %w[yml json]
    expected = fixtures.flat_map do |fixture|
      relative = fixture.delete_prefix("spec/fixtures/")
      formats.map { |extension| "#{relative}.#{extension}" }
    end
    actual = Dir.glob("**/*.{yml,json}", base: File.join(root, "spec/golden"))

    expect(actual - expected).to be_empty
  end

  fixtures.each do |fixture|
    context fixture do
      let(:analysis) do
        result = PngConform::Services::ValidationService.validate_file(
          File.join(root, fixture),
        )
        result.file_path = fixture
        result
      end

      { "yml" => PngConform::Reporters::YamlReporter,
        "json" => PngConform::Reporters::JsonReporter }.each do |extension, reporter|
        it "matches the #{extension} reporter golden byte for byte" do
          output = StringIO.new
          reporter.new(output).report(analysis)
          relative = fixture.delete_prefix("spec/fixtures/")
          golden = File.join(root, "spec/golden", "#{relative}.#{extension}")

          # Explicit opt-in only: ordinary spec runs never repair goldens.
          if ENV["REGENERATE_REPORT_GOLDENS"] == "1"
            FileUtils.mkdir_p(File.dirname(golden))
            File.binwrite(golden, output.string)
          end

          expect(output.string.b).to eq(File.binread(golden))
        end
      end
    end
  end
end
