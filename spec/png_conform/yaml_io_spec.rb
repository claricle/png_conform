# frozen_string_literal: true

require "png_conform/yaml_io"
require "tempfile"
require "stringio"

RSpec.describe PngConform::YamlIO do
  let(:file) do
    Tempfile.new(["yaml_io", ".yml"]).tap do |f|
      f.write(yaml)
      f.flush
    end
  end
  let(:path) { file.path }
  let(:data) { { "name" => "PNG", "versions" => [1, 2] } }
  let(:yaml) { "name: PNG\nversions: [1, 2]\n" }

  after { file.close! }

  describe "Yeptris runtime dependency" do
    subject(:requirement) do
      gemspec = Gem::Specification.load(
        File.expand_path("../../png_conform.gemspec", __dir__),
      )
      gemspec.runtime_dependencies.find { |dependency| dependency.name == "yeptris" }
        .requirement
    end

    it "accepts the glossarist-compatible window and later builds" do
      expect(requirement).to be_satisfied_by(Gem::Version.new("0.6.59"))
      expect(requirement).to be_satisfied_by(Gem::Version.new("0.6.62.1"))
    end

    it "rejects releases older than the glossarist-compatible floor" do
      expect(requirement).not_to be_satisfied_by(Gem::Version.new("0.6.58"))
    end

    it "rejects releases outside the 0.6 series" do
      expect(requirement).not_to be_satisfied_by(Gem::Version.new("0.7.0"))
      expect(requirement).not_to be_satisfied_by(Gem::Version.new("1.0.0"))
    end
  end

  describe ".load_file" do
    it "loads a YAML file" do
      expect(described_class.load_file(path)).to eq(data)
    end

    it "forwards keyword options to Yeptris" do
      expect(described_class.load_file(path, symbolize_names: true))
        .to eq(name: "PNG", versions: [1, 2])
    end
  end

  describe ".safe_load_file" do
    it "loads a YAML file safely" do
      expect(described_class.safe_load_file(path)).to eq(data)
    end

    context "with a symbol" do
      let(:yaml) { "--- !ruby/symbol png\n" }

      it "rejects unpermitted classes" do
        expect { described_class.safe_load_file(path) }
          .to raise_error(Yeptris::Psych::DisallowedClass)
      end

      it "forwards permitted classes" do
        expect(described_class.safe_load_file(path, permitted_classes: [Symbol]))
          .to eq(:png)
      end
    end

    it "forwards Yeptris's missing-file fallback option" do
      expect(described_class.safe_load_file("#{path}.missing", fallback: true))
        .to be(false)
    end
  end

  describe ".parse_file" do
    it "returns a Yeptris document AST" do
      document = described_class.parse_file(path)

      expect(document).to be_a(Yeptris::Psych::Nodes::Document)
      expect(document.children.first).to be_a(Yeptris::Psych::Nodes::Mapping)
    end

    context "with invalid YAML" do
      let(:yaml) { "name: [\n" }

      it "propagates parsing errors" do
        expect { described_class.parse_file(path) }
          .to raise_error(Yeptris::Psych::SyntaxError)
      end
    end
  end

  describe ".dump" do
    it "serializes without calling the object's to_yaml" do
      allow(data).to receive(:to_yaml).and_raise("must not call to_yaml")

      expect(Yeptris::Psych.safe_load(described_class.dump(data))).to eq(data)
    end

    it "forwards an output stream and dump options" do
      output = StringIO.new

      expect(described_class.dump(data, output, indentation: 4)).to equal(output)
      expect(Yeptris::Psych.safe_load(output.string)).to eq(data)
    end
  end
end
