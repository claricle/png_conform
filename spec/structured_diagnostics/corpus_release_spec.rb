# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "rake"
require "tmpdir"

RSpec.describe "Diagnostic corpus release integration" do
  let(:root) { File.expand_path("../..", __dir__) }

  it "checks the committed corpus successfully through the script" do
    out, err, status = Open3.capture3(
      RbConfig.ruby, "script/regenerate_diagnostic_goldens", "--check", chdir: root
    )
    count = Dir.glob(File.join(root, "spec/fixtures/diagnostics/**/*.json")).size

    expect(count).to be_positive
    expect(status.exitstatus).to eq(0), err
    expect(out).to eq("#{count} goldens match\n")
  end

  it "keeps the corpus check in the default task even when goldens are absent" do
    original = Rake.application
    Rake.application = Rake::Application.new
    allow(Dir).to receive(:exist?).and_call_original
    allow(Dir).to receive(:exist?).with("spec/fixtures/diagnostics").and_return(false)
    load File.join(root, "Rakefile")

    expect(Rake::Task.task_defined?("diagnostics:check")).to be(true)
    expect(Rake::Task[:default].prerequisites).to include("diagnostics:check")
  ensure
    Rake.application = original
  end

  it "preserves the filename override on the canonical report" do
    input = "spec/fixtures/pngsuite/basic/non_interlaced/basn0g01.png"
    result = PngConform::Services::ValidationService.validate_file(input).validation_result

    expect(result.to_lens_report(filename: input).to_h)
      .to include("file" => input)
  end

  it "reports a huge truncated chunk through the JSON CLI" do
    Dir.mktmpdir("oversized-chunk") do |dir|
      path = File.join(dir, "big.png")
      fixture = File.binread(File.join(root, "spec/fixtures/pngsuite/basic/non_interlaced/basn0g01.png"))
      File.binwrite(path, "#{fixture.byteslice(0, 33)}#{[0x7ffffff0].pack('N')}IDAT#{'x' * 20}")
      out, = Open3.capture3(RbConfig.ruby, "exe/png_conform", "check", "-f", "json", path,
                            chdir: root)

      expect(JSON.parse(out).fetch("diagnostics"))
        .to include(include("requirement_id" => "all.chunk.length-exceeds-data"))
    end
  end
end
