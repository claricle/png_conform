# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require_relative "../support/diagnostic_corpus"

RSpec.describe "Diagnostic corpus write failures" do
  let(:root) { Dir.mktmpdir("corpus-write") }
  let(:corpus) { PngConform::DiagnosticCorpus.new(root) }
  let(:target) { File.join(root, PngConform::DiagnosticCorpus::GOLDENS) }
  let(:inputs) { %w[spec/fixtures/pngsuite/a.png spec/fixtures/pngsuite/b.png] }

  after { FileUtils.rm_rf(root) }

  before do
    inputs.each do |input|
      path = File.join(root, input)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, "input")
    end
    allow(corpus).to receive(:render).and_return("old\n")
  end

  def contents
    corpus.goldens.to_h { |path| [path, File.binread(File.join(root, path))] }
  end

  [false, true].each do |existing|
    it "preserves #{existing ? 'existing' : 'absent'} goldens when staging fails" do
      corpus.write if existing
      original = contents
      allow(corpus).to receive(:render).and_return("new\n")
      allow(File).to receive(:binwrite).and_wrap_original do |method, path, text|
        raise Errno::ENOSPC if path.end_with?("b.png.json")

        method.call(path, text)
      end

      expect { corpus.write }.to raise_error(Errno::ENOSPC)
      expect(contents).to eq(original)
      expect(Dir.exist?(target)).to eq(existing)
    end
  end

  it "refuses hidden orphan files without changing the tree" do
    corpus.write
    hidden = File.join(target, ".stray")
    File.binwrite(hidden, "keep")
    original = contents

    expect { corpus.write }.to raise_error(/dirty golden tree/)
    expect(contents).to eq(original)
    expect(corpus.check.map(&:kind)).to include(:extra)
  end

  it "retains a recoverable backup if rollback also fails" do
    corpus.write
    allow(File).to receive(:rename).and_wrap_original do |method, source, destination|
      raise Errno::EACCES if destination == target

      method.call(source, destination)
    end

    expect { corpus.write }.to raise_error(/backup preserved at/)
    backups = Dir.glob(File.join(root, "spec/fixtures/diagnostic-goldens-*/backup/**/*.json"))
    expect(backups.size).to eq(inputs.size)
    expect(backups.map { |path| File.binread(path) }).to eq(["old\n"] * inputs.size)
  end

  it "restores the old tree when installing the staged tree fails" do
    corpus.write
    original = contents
    allow(corpus).to receive(:render).and_return("new\n")
    allow(File).to receive(:rename).and_wrap_original do |method, source, destination|
      raise Errno::EACCES if File.basename(source) == "replacement"

      method.call(source, destination)
    end

    expect { corpus.write }.to raise_error(Errno::EACCES)
    expect(contents).to eq(original)
  end
end
