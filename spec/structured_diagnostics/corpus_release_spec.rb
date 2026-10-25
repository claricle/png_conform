# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "rake"
require "bundler/gem_tasks"
require "tmpdir"
require_relative "../support/diagnostic_corpus"

RSpec.describe "Diagnostic corpus release integration" do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:root) { Dir.mktmpdir("corpus-release") }
  let(:corpus) { PngConform::DiagnosticCorpus.new(root) }
  let(:goldens) { File.join(root, "spec/fixtures/diagnostics") }

  before do
    FileUtils.mkdir_p(File.join(root, "spec/structured_diagnostics"))
    FileUtils.mkdir_p(File.join(root, "spec/fixtures"))
    %w[mng jng].each do |format|
      FileUtils.cp_r(File.join(repo_root, "spec/fixtures", format),
                     File.join(root, "spec/fixtures"))
    end
    FileUtils.cp(File.join(repo_root, "spec/structured_diagnostics/corpus_spec.rb"),
                 File.join(root, "spec/structured_diagnostics"))
  end

  after { FileUtils.rm_rf(root) }

  def load_tasks
    original = Rake.application
    Rake.application = Rake::Application.new
    Dir.chdir(root) { load File.join(repo_root, "Rakefile") }
    yield
  ensure
    Rake.application = original
  end

  def release_examples
    out, err, status = Open3.capture3(
      RbConfig.ruby, "-S", "rspec",
      File.join(root, "spec/structured_diagnostics/corpus_spec.rb"),
      "--options", File::NULL, "--require", "spec_helper",
      "--format", "json", chdir: repo_root
    )
    [JSON.parse(out), status, err]
  end

  it "keeps the default task free of corpus checks before regeneration" do
    load_tasks do
      expect(Rake::Task.task_defined?("goldens:check")).to be(false)
      expect(Rake::Task[:default].prerequisites).to eq(%w[spec rubocop])
    end
    expect(Dir.exist?(goldens)).to be(false)
  end

  it "enables the default corpus gate after goldens exist" do
    corpus.write
    load_tasks do
      expect(Rake::Task.task_defined?("goldens:check")).to be(true)
      expect(Rake::Task[:default].prerequisites).to include("goldens:check")
    end
  end

  it "defers the release examples without generating a baseline" do
    report, status, err = release_examples

    expect(status.exitstatus).to eq(0), err
    expect(report.fetch("examples")).not_to be_empty
    expect(report.fetch("examples").map { |example| example.fetch("status") }.uniq)
      .to eq(["pending"])
    expect(Dir.exist?(goldens)).to be(false)
  end

  it "runs the release examples and rejects drift after regeneration" do
    corpus.write
    report, status, err = release_examples
    expect(status.exitstatus).to eq(0), err
    expect(report.fetch("summary").fetch("pending_count")).to eq(0)
    path = File.join(root, corpus.goldens.first)
    File.binwrite(path, "{}\n")

    report, status, = release_examples
    expect(status.exitstatus).to eq(1)
    expect(report.fetch("summary").fetch("failure_count")).to be_positive
    expect(File.binread(path)).to eq("{}\n")
  end
end
