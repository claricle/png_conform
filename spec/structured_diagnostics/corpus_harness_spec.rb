# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "tmpdir"
require "yaml"
require_relative "../support/diagnostic_corpus"

RSpec.describe "Structured diagnostic corpus" do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:script) { File.join(repo_root, "script/regenerate_diagnostic_goldens") }

  # A scratch repo root holding one input per format, copied from the real
  # fixtures, so the harness is exercised without the full corpus.
  describe "harness behaviour" do
    let(:root) { Dir.mktmpdir("diagnostic-corpus") }
    let(:corpus) { PngConform::DiagnosticCorpus.new(root) }
    let(:copied) do
      %w[
        spec/fixtures/pngsuite/basic/non_interlaced/basn0g01.png
        spec/fixtures/mng/valid-minimal.mng
        spec/fixtures/jng/invalid-missing-jdat.jng
      ]
    end

    before do
      copied.each do |path|
        FileUtils.mkdir_p(File.join(root, File.dirname(path)))
        FileUtils.cp(File.join(repo_root, path), File.join(root, path))
      end
    end

    after { FileUtils.rm_rf(root) } # best effort: Windows may still hold input handles

    def golden(path)
      File.join(root, corpus.golden_path(path))
    end

    it "lists inputs across formats in bytewise sorted order" do
      expect(corpus.inputs).to eq(copied.sort_by(&:b))
    end

    it "names each golden by mirroring the input path" do
      expect(corpus.golden_path(copied.first))
        .to eq("spec/fixtures/diagnostics/pngsuite/basic/non_interlaced/" \
               "basn0g01.png.json")
    end

    it "reports every input missing before any write" do
      expect(corpus.check.map(&:kind)).to eq(%i[missing] * copied.size)
    end

    it "writes one golden per input without host paths" do
      corpus.write
      expect(corpus.goldens.size).to eq(copied.size)
      text = File.read(golden(copied.first))
      expect(JSON.parse(text).fetch("file")).to eq(copied.first)
      expect(text).not_to include(root)
    end

    it "is byte-identical on repeated generation" do
      first = corpus.write.to_h { |p| [p, File.binread(File.join(root, p))] }
      second = corpus.write.to_h { |p| [p, File.binread(File.join(root, p))] }
      expect(second).to eq(first)
    end

    it "compares non-ASCII reports byte for byte" do
      input = "spec/fixtures/pngsuite/ancillary/text/ctfn0g04.png"
      FileUtils.mkdir_p(File.join(root, File.dirname(input)))
      FileUtils.cp(File.join(repo_root, input), File.join(root, input))
      corpus.write

      expect(corpus.check).to be_empty
    end

    context "when validation raises on an input" do
      before do
        allow(PngConform::Services::ValidationService)
          .to receive(:validate_file).and_raise(Errno::EINVAL)
      end

      it "refuses to write and leaves no partial goldens" do
        expect { corpus.write }
          .to raise_error(PngConform::DiagnosticCorpus::RenderError)
        expect(corpus.goldens).to be_empty
      end
    end

    context "with a written corpus" do
      before { corpus.write }

      def kinds
        corpus.check.map(&:kind)
      end

      it "reports an input that cannot be rendered" do
        allow(PngConform::Services::ValidationService)
          .to receive(:validate_file).and_raise(Errno::EINVAL)
        expect(kinds).to include(:render)
      end

      it "detects a missing golden" do
        File.delete(golden(copied.first))
        expect(kinds).to include(:missing)
      end

      it "detects an extra golden" do
        extra = File.join(root, "spec/fixtures/diagnostics/mng/ghost.mng.json")
        File.write(extra, "{}\n")
        expect(kinds).to include(:extra)
      end

      it "detects a stale golden" do
        document = JSON.parse(File.read(golden(copied.first)))
        document["valid"] = !document["valid"]
        File.write(golden(copied.first), JSON.pretty_generate(document))
        expect(kinds).to include(:stale)
      end

      it "detects reordered output" do
        document = JSON.parse(File.read(golden(copied.first)))
        File.write(golden(copied.first),
                   JSON.pretty_generate(document.to_a.reverse.to_h) << "\n")
        expect(kinds).to include(:reordered)
      end

      it "detects host-dependent paths" do
        problems = PngConform::DiagnosticCorpus.document_problems(
          "x.json", JSON.generate("schema_version" => LensCore::SCHEMA_VERSION,
                                  "filename" => "/Users/someone/x.png")
        )
        expect(problems.map(&:kind)).to eq(%i[host])
      end

      it "refuses a schema version it does not understand" do
        problems = PngConform::DiagnosticCorpus.document_problems(
          "x.json", JSON.generate("schema_version" => LensCore::SCHEMA_VERSION + 1)
        )
        expect(problems.map(&:kind)).to eq(%i[schema])
      end

      it "does not write while checking" do
        File.delete(golden(copied.first))
        corpus.check
        expect(File).not_to exist(golden(copied.first))
      end

      it "refuses to write over a dirty golden tree" do
        File.write(File.join(root, "spec/fixtures/diagnostics/stray.txt"), "x")
        expect { corpus.write }.to raise_error(/dirty golden tree/)
      end
    end
  end

  describe "script/regenerate_diagnostic_goldens" do
    it "rejects an unknown option with status 2" do
      _out, _err, status = Open3.capture3(RbConfig.ruby, script, "--bogus", chdir: repo_root)
      expect(status.exitstatus).to eq(2)
    end

    it "requires exactly one mode" do
      _out, _err, status = Open3.capture3(RbConfig.ruby, script, "--check", "--write",
                                          chdir: repo_root)
      expect(status.exitstatus).to eq(2)
    end
  end
end
