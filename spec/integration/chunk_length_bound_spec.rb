# frozen_string_literal: true

require "spec_helper"
require "stringio"

# A declared chunk length above the PNG limit or the remaining bytes is a
# cataloged diagnostic on every host, raised before any allocation for it.
RSpec.describe "Chunk length bound" do
  let(:corrupted_dir) do
    File.expand_path("../fixtures/pngsuite/corrupted", __dir__)
  end
  let(:signature) { [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack("C*") }

  def analyze(reader_type, path)
    if reader_type == :full_load
      reader = PngConform::Readers::FullLoadReader.new(path)
      begin
        PngConform::Services::ValidationOrchestrator.new(reader, path).validate
      ensure
        reader.close
      end
    else
      PngConform::Container.open_reader(reader_type, path) do |streaming|
        PngConform::Container
          .validation_orchestrator(streaming, path, {}).validate
      end
    end
  end

  def analyze_bytes(bytes)
    reader = PngConform::Readers::StreamingReader.new(StringIO.new(bytes))
    reader.read_signature
    PngConform::Services::ValidationOrchestrator.new(reader).validate
  end

  def framing_findings(analysis)
    analysis.errors.select { |e| e.requirement_id.to_s.start_with?("all.chunk.") }
  end

  def chunk(type, data = "")
    [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
  end

  %i[streaming full_load].each do |reader_type|
    context "with xlfn0g04.png read by the #{reader_type} reader" do
      let(:analysis) do
        analyze(reader_type, File.join(corrupted_dir, "xlfn0g04.png"))
      end

      it "reports the over-limit length with a stable ID and message" do
        findings = framing_findings(analysis)

        expect(findings.map(&:requirement_id))
          .to eq(["all.chunk.length-exceeds-limit"])
        expect(findings.first.message)
          .to eq("Chunk length 3787991296 exceeds the maximum 2147483647")
        expect(findings.first.chunk_offset).to eq(30)
        expect(analysis).not_to be_valid
      end

      it "still reports the well-framed IHDR and the bad signature" do
        expect(analysis.errors.map(&:requirement_id))
          .to include("all.signature.unknown")
        expect(analysis.chunks.map(&:type)).to eq(["IHDR"])
      end
    end
  end

  describe "a length beyond the remaining bytes but within the limit" do
    let(:bytes) do
      "#{signature}#{chunk('IHDR', [1, 1, 8, 0, 0, 0, 0].pack('NNCCCCC'))}#{[100].pack('N')}IDAT#{'x' * 20}"
    end

    it "reports the remaining-bytes diagnostic and stops reading" do
      analysis = analyze_bytes(bytes)
      finding = framing_findings(analysis).first

      expect(framing_findings(analysis).size).to eq(1)
      expect(finding.requirement_id).to eq("all.chunk.length-exceeds-data")
      expect(finding.message)
        .to eq("Chunk length 100 exceeds the 16 data bytes remaining")
      expect(finding.chunk_offset).to eq(33)
    end
  end

  describe "the limit boundary" do
    def header_only(length)
      "#{signature}#{[length].pack('N')}IDAT#{'x' * 16}"
    end

    it "treats 2^31-1 as within the limit (the data check applies)" do
      ids = framing_findings(analyze_bytes(header_only((2**31) - 1))).map(&:requirement_id)
      expect(ids).to eq(["all.chunk.length-exceeds-data"])
    end

    it "treats 2^31 as over the limit" do
      ids = framing_findings(analyze_bytes(header_only(2**31))).map(&:requirement_id)
      expect(ids).to eq(["all.chunk.length-exceeds-limit"])
    end
  end

  describe "preservation" do
    it "adds no framing finding to a well-framed PNG" do
      path = File.expand_path("../fixtures/pngsuite/basic/non_interlaced/basn0g01.png", __dir__)
      %i[streaming full_load].each do |reader_type|
        analysis = analyze(reader_type, path)
        expect(framing_findings(analysis)).to be_empty
        expect(analysis.chunks.map(&:type).last).to eq("IEND")
      end
    end

    it "adds no framing finding to the other corrupted fixtures" do
      others = Dir[File.join(corrupted_dir, "*.png")]
        .reject { |f| File.basename(f) == "xlfn0g04.png" }
      expect(others).not_to be_empty
      others.each do |path|
        expect(framing_findings(analyze(:streaming, path))).to be_empty,
                                                               File.basename(path)
      end
    end

    it "reads a file whose last chunk ends exactly at end of file" do
      bytes = signature + chunk("IEND")
      expect(framing_findings(analyze_bytes(bytes))).to be_empty
    end
  end
end
