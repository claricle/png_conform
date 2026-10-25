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

  it "checks the reviewed corpus inherited from main without regenerating it" do
    inherited = PngConform::DiagnosticCorpus.new(repo_root)
    expect(inherited.goldens).not_to be_empty
    expect(inherited.check).to be_empty
  end

  it "preserves the documented diagnostics check task alongside the goldens alias" do
    corpus.write
    load_tasks do
      expect(Rake::Task.task_defined?("diagnostics:check")).to be(true)
      expect(Rake::Task["goldens:check"].prerequisites).to include("diagnostics:check")
    end
  end

  it "keeps the default corpus gate enabled if the inherited goldens are removed" do
    load_tasks do
      expect(Rake::Task.task_defined?("goldens:check")).to be(true)
      expect(Rake::Task[:default].prerequisites).to eq(%w[spec rubocop diagnostics:check])
    end
    expect(Dir.exist?(goldens)).to be(false)
  end

  it "enables the default corpus gate after goldens exist" do
    corpus.write
    load_tasks do
      expect(Rake::Task.task_defined?("goldens:check")).to be(true)
      expect(Rake::Task[:default].prerequisites).to include("diagnostics:check")
    end
  end

  it "fails the release examples if the inherited baseline is missing" do
    report, status, err = release_examples

    expect(status.exitstatus).to eq(1), err
    expect(report.fetch("summary").fetch("failure_count")).to be_positive
    expect(report.fetch("summary").fetch("pending_count")).to eq(0)
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
