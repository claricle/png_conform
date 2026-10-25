# frozen_string_literal: true

require "spec_helper"
require "png_conform/diagnostics/golden_generator"
require "tmpdir"
require "stringio"
require "open3"
require "rbconfig"

RSpec.describe PngConform::Diagnostics::GoldenGenerator do
  let(:output) { StringIO.new }
  let(:generator) { described_class.new(root: root, output: output) }
  let(:png) { "pngsuite/Z.png" }
  let(:mng) { "mng/valid.mng" }
  let(:jng) { "jng/valid.jng" }

  let(:root) { Dir.mktmpdir("diagnostic-goldens") }

  after { FileUtils.remove_entry(root) }

  before do
    copy_fixture("pngsuite/basic/non_interlaced/basn0g01.png", png)
    copy_fixture("mng/valid-minimal.mng", mng)
    copy_fixture("jng/valid-minimal.jng", jng)
    # A signature-only PNG produces multiple diagnostics in emission order.
    File.binwrite(File.join(root, "spec/fixtures/pngsuite/a.png"),
                  "\x89PNG\r\n\x1a\n".b)
  end

  def copy_fixture(source, target)
    destination = File.join(root, "spec/fixtures", target)
    FileUtils.mkdir_p(File.dirname(destination))
    FileUtils.cp(File.expand_path("../../fixtures/#{source}", __dir__),
                 destination)
  end

  def snapshot
    Dir.glob("#{root}/**/*").to_h do |path|
      [path, [File.stat(path).mtime, File.file?(path) ? File.binread(path) : nil]]
    end
  end

  def golden(path)
    File.join(goldens, "#{path}.json")
  end

  def goldens
    File.join(root, "spec/fixtures/diagnostics")
  end

  it "writes byte-identical reports twice and then checks successfully" do
    expect(generator.run(["--write"])).to eq(0)
    first = Dir.glob("#{goldens}/**/*.json").to_h { |p| [p, File.binread(p)] }
    expect(first.size).to eq(4)
    expect(generator.run(["--write"])).to eq(0)
    expect(first.keys.to_h { |path| [path, File.binread(path)] })
      .to eq(first)
    before_check = snapshot
    expect(generator.run(["--check"])).to eq(0)
    expect(snapshot).to eq(before_check)
  end

  %w[ctfn0g04 ctgn0g04 cthn0g04 ctjn0g04].each do |name|
    it "checks freshly written non-ASCII diagnostics from #{name} by bytes" do
      fixture = "pngsuite/ancillary/text/#{name}.png"
      copy_fixture(fixture, fixture)
      expect(generator.run(["--write"])).to eq(0)
      expect(File.binread(golden(fixture)).ascii_only?).to be(false)
      original = snapshot

      expect(generator.run(["--check"])).to eq(0)
      expect(output.string).to include("5 goldens match")
      expect(snapshot).to eq(original)
    end
  end

  it "validates all formats through the normal service in bytewise path order" do
    paths = []
    allow(PngConform::Services::ValidationService).to receive(:validate_file)
      .and_wrap_original do |method, path|
        paths << path.delete_prefix("#{root}/")
        method.call(path)
      end
    generator.run(["--write"])
    expect(paths).to eq(["spec/fixtures/jng/valid.jng",
                         "spec/fixtures/mng/valid.mng",
                         "spec/fixtures/pngsuite/Z.png",
                         "spec/fixtures/pngsuite/a.png"])
  end

  it "writes valid LensCore reports without timestamps or host paths" do
    generator.run(["--write"])
    [png, mng, jng].each do |path|
      report = JSON.parse(File.binread(golden(path)))
      expect(report).to include("valid" => true,
                                "file" => "spec/fixtures/#{path}")
      expect(report).not_to have_key("timestamp")
      expect(report).not_to have_key("extensions")
      expect(File.binread(golden(path))).not_to include(root)
      expect(LensCore::Report.from_h(report).to_h).to eq(report)
    end
  end

  it "preserves informational diagnostics on valid files" do
    generator.run(["--write"])
    report = JSON.parse(File.binread(golden(png)))
    expect(report.fetch("valid")).to be(true)
    expect(report.fetch("diagnostics")).to include(
      include("severity" => "info",
              "requirement_id" => "info.png.gAMA.gamma-linear"),
    )
  end

  it "writes empty diagnostics when validation emits no findings" do
    generator.run(["--write"])
    [mng, jng].each do |path|
      expect(JSON.parse(File.binread(golden(path))))
        .to include("valid" => true, "diagnostics" => [])
    end
  end

  it "preserves warnings alongside info without changing validity or order" do
    allow(PngConform::Services::ValidationService).to receive(:validate_file)
      .and_wrap_original do |method, path|
        method.call(path).tap do |analysis|
          analysis.validation_result.warning("An advisory")
        end
      end
    generator.run(["--write"])
    report = JSON.parse(File.binread(golden(png)))
    expect(report.fetch("valid")).to be(true)
    expect(report.fetch("diagnostics").map { |d| d.fetch("severity") })
      .to eq(%w[info warning])
  end

  it "serializes exactly the report hash with diagnostics in emission order" do
    generator.run(["--write"])
    path = "spec/fixtures/pngsuite/a.png"
    result = PngConform::Services::ValidationService.validate_file(
      File.join(root, path),
    ).validation_result
    expect(result.diagnostics.size).to be > 1
    expect(File.binread(golden("pngsuite/a.png"))).to eq(
      "#{JSON.pretty_generate(result.to_lens_report(filename: path).to_h)}\n",
    )
  end

  it "omits the optional filename unless explicitly supplied" do
    result = PngConform::Models::ValidationResult.new(filename: "/host/a.png")
    expect(result.to_lens_report.to_h).not_to have_key("file")
    expect(result.to_lens_report(filename: "spec/fixtures/a.png").to_h)
      .to include("file" => "spec/fixtures/a.png")
  end

  it "reports missing goldens without creating the output directory" do
    original = snapshot
    expect(generator.run(["--check"])).to eq(1)
    expect(output.string.scan("missing:").size).to eq(4)
    expect(File.exist?(goldens)).to be(false)
    expect(snapshot).to eq(original)
  end

  context "with existing goldens" do
    before do
      generator.run(["--write"])
      output.truncate(0)
      output.rewind
    end

    it "identifies an unreadable golden as a check failure without writes" do
      path = golden(png)
      original = snapshot
      allow(File).to receive(:binread).and_call_original
      allow(File).to receive(:binread).with(path).and_raise(Errno::EACCES, path)

      expect(generator.run(["--check"])).to eq(1)
      expect(output.string).to include("check failed:", "Permission denied", path)
      expect(output.string).not_to include("refusing to write")
      allow(File).to receive(:binread).with(path).and_call_original
      expect(snapshot).to eq(original)
    end

    it "reports missing, extra and stale files together without writes" do
      File.delete(golden(png))
      File.binwrite(golden("extra.png"), "{}\n")
      File.binwrite(golden(mng), "{}\n")
      original = snapshot
      expect(generator.run(["--check"])).to eq(1)
      expect(output.string).to include("missing:", "extra:", "stale")
      expect(snapshot).to eq(original)
    end

    it "detects reordered diagnostics without repairing them" do
      path = golden("pngsuite/a.png")
      report = JSON.parse(File.binread(path))
      report.fetch("diagnostics").reverse!
      File.binwrite(path, "#{JSON.pretty_generate(report)}\n")
      original = snapshot
      expect(generator.run(["--check"])).to eq(1)
      expect(output.string).to include("ordering differs", "pngsuite/a.png.json")
      expect(snapshot).to eq(original)
    end

    it "detects reordered JSON keys even when decoded reports compare equal" do
      path = golden(png)
      report = JSON.parse(File.binread(path))
      File.binwrite(path, "#{JSON.pretty_generate(report.to_a.reverse.to_h)}\n")
      original = snapshot
      expect(generator.run(["--check"])).to eq(1)
      expect(output.string).to include("ordering differs")
      expect(snapshot).to eq(original)
    end

    it "refuses to write over an extra target set" do
      File.binwrite(golden("extra.png"), "{}\n")
      original = snapshot
      expect(generator.run(["--write"])).to eq(1)
      expect(output.string).to include("extra:")
      expect(snapshot).to eq(original)
    end
  end

  [[], ["--unknown"], ["--write", "--unknown"], ["--check", "--write"]].each do |args|
    it "rejects #{args.inspect} without writes" do
      original = snapshot
      expect(generator.run(args)).to eq(2)
      expect(output.string).to include("Usage:")
      expect(snapshot).to eq(original)
    end
  end

  it "exposes an executable script which rejects unknown options" do
    script = File.expand_path("../../../script/regenerate_diagnostic_goldens", __dir__)
    text, status = Open3.capture2e(RbConfig.ruby, script, "--unknown", chdir: root)
    expect(status.exitstatus).to eq(2)
    expect(text).to include("Usage:")
  end
end
