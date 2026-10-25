# frozen_string_literal: true

require "spec_helper"
require "png_conform/diagnostics/golden_generator"
require "open3"
require "tmpdir"
require "fileutils"

RSpec.describe "Diagnostic corpus script dispatch" do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:script) { File.join(repo_root, "script/regenerate_diagnostic_goldens") }
  let(:root) { Dir.mktmpdir("corpus-script") }

  after { FileUtils.rm_rf(root) }

  %w[-c --ch -w --wr].each do |option|
    it "rejects #{option} without writing goldens" do
      FileUtils.mkdir_p(File.join(root, "script"))
      FileUtils.mkdir_p(File.join(root, "spec/support"))
      FileUtils.mkdir_p(File.join(root, "spec/fixtures/pngsuite"))
      FileUtils.cp(script, File.join(root, "script/regenerate_diagnostic_goldens"))
      FileUtils.cp_r(File.join(repo_root, "lib"), root)
      FileUtils.cp_r(File.join(repo_root, "config"), root)
      FileUtils.cp(File.join(repo_root, "spec/support/diagnostic_corpus.rb"),
                   File.join(root, "spec/support"))
      FileUtils.cp(File.join(repo_root, "spec/fixtures/pngsuite/basic/non_interlaced/basn0g01.png"),
                   File.join(root, "spec/fixtures/pngsuite/a.png"))

      out, err, status = Open3.capture3(RbConfig.ruby,
                                        File.join(root, "script/regenerate_diagnostic_goldens"), option)

      expect(status.exitstatus).to eq(2), out + err
      expect(out + err).to include("Usage:")
      expect(Dir.exist?(File.join(root, "spec/fixtures/diagnostics"))).to be(false)
    end
  end

  it "dispatches through the existing GoldenGenerator entry point" do
    generator = instance_double(PngConform::Diagnostics::GoldenGenerator)
    allow(PngConform::Diagnostics::GoldenGenerator).to receive(:new)
      .with(root: repo_root).and_return(generator)
    allow(generator).to receive(:run).with(["--check"]).and_return(7)
    arguments = ARGV.dup
    ARGV.replace(["--check"])

    expect { load script }.to raise_error(SystemExit) { |error| expect(error.status).to eq(7) }
    expect(generator).to have_received(:run).with(["--check"])
  ensure
    ARGV.replace(arguments)
  end
end
