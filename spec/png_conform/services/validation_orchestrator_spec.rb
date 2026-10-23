# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Services::ValidationOrchestrator do
  describe "#validate" do
    context "with valid PNG structure" do
      let(:reader) { create_mock_reader(valid_chunks) }
      let(:orchestrator) { described_class.new(reader, "test.png") }

      let(:valid_chunks) do
        [
          create_bindata_chunk("IHDR", 0, 13),
          create_bindata_chunk("IDAT", 21, 100),
          create_bindata_chunk("IEND", 133, 0),
        ]
      end

      it "returns a file analysis" do
        result = orchestrator.validate
        expect(result).to be_a(PngConform::Models::FileAnalysis)
        expect(result.validation_result).to be_a(PngConform::Models::ValidationResult)
      end

      it "validates the PNG signature" do
        result = orchestrator.validate
        # Should not have signature errors for valid structure
        signature_errors = result.errors.select do |e|
          e.message.include?("signature")
        end
        expect(signature_errors).to be_empty
      end

      it "validates chunk sequence" do
        result = orchestrator.validate
        # IHDR first, IEND last, IDAT present - should be valid
        expect(result.error_count).to eq(0)
      end
    end

    context "with missing IHDR" do
      let(:reader) { create_mock_reader(chunks_without_ihdr) }
      let(:orchestrator) { described_class.new(reader, "test.png") }

      let(:chunks_without_ihdr) do
        [
          create_bindata_chunk("IDAT", 0, 100),
          create_bindata_chunk("IEND", 112, 0),
        ]
      end

      it "adds error for missing IHDR" do
        result = orchestrator.validate
        expect(result.error_count).to be > 0
        ihdr_errors = result.errors.select { |e| e.message.include?("IHDR") }
        expect(ihdr_errors).not_to be_empty
      end
    end

    context "with missing IEND" do
      let(:reader) { create_mock_reader(chunks_without_iend) }
      let(:orchestrator) { described_class.new(reader, "test.png") }

      let(:chunks_without_iend) do
        [
          create_bindata_chunk("IHDR", 0, 13),
          create_bindata_chunk("IDAT", 21, 100),
        ]
      end

      it "adds error for missing IEND" do
        result = orchestrator.validate
        expect(result.error_count).to be > 0
        iend_errors = result.errors.select { |e| e.message.include?("IEND") }
        expect(iend_errors).not_to be_empty
      end
    end

    context "with missing IDAT" do
      let(:reader) { create_mock_reader(chunks_without_idat) }
      let(:orchestrator) { described_class.new(reader, "test.png") }

      let(:chunks_without_idat) do
        [
          create_bindata_chunk("IHDR", 0, 13),
          create_bindata_chunk("IEND", 21, 0),
        ]
      end

      it "adds error for missing IDAT" do
        result = orchestrator.validate
        expect(result.error_count).to be > 0
        idat_errors = result.errors.select { |e| e.message.include?("IDAT") }
        expect(idat_errors).not_to be_empty
      end
    end

    context "with unknown critical chunk" do
      let(:reader) { create_mock_reader(chunks_with_unknown_critical) }
      let(:orchestrator) { described_class.new(reader, "test.png") }

      let(:chunks_with_unknown_critical) do
        [
          create_bindata_chunk("IHDR", 0, 13),
          create_bindata_chunk("ABCD", 21, 10), # Unknown critical (uppercase first letter)
          create_bindata_chunk("IDAT", 43, 100),
          create_bindata_chunk("IEND", 155, 0),
        ]
      end

      it "adds error for unknown critical chunk" do
        result = orchestrator.validate
        expect(result.error_count).to be > 0
        unknown_errors = result.errors.select do |e|
          e.message.include?("Unknown") && e.message.include?("critical")
        end
        expect(unknown_errors).not_to be_empty
      end
    end

    context "with unknown ancillary chunk" do
      let(:reader) { create_mock_reader(chunks_with_unknown_ancillary) }
      let(:orchestrator) { described_class.new(reader, "test.png") }

      let(:chunks_with_unknown_ancillary) do
        [
          create_bindata_chunk("IHDR", 0, 13),
          create_bindata_chunk("abcd", 21, 10), # Unknown ancillary (lowercase first letter)
          create_bindata_chunk("IDAT", 43, 100),
          create_bindata_chunk("IEND", 155, 0),
        ]
      end

      it "does not add error for unknown ancillary chunk" do
        result = orchestrator.validate
        # Unknown ancillary chunks are allowed per PNG spec
        # Check that there are no critical chunk errors
        unknown_critical_errors = result.errors.select do |e|
          e.message.include?("Unknown") && e.message.include?("critical")
        end
        expect(unknown_critical_errors).to be_empty
      end
    end
  end

  describe "format-aware dispatch" do
    let(:png_sig) { [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack("C*") }
    let(:mng_sig) { [0x8A, 0x4D, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack("C*") }
    let(:jng_sig) { [0x8B, 0x4A, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack("C*") }

    # Validate a mock stream of [type, length] pairs under the given signature.
    def run(signature, types)
      offset = 8
      chunks = types.map do |type|
        chunk = create_bindata_chunk(type, offset, type == "IDAT" ? 4 : 0)
        offset += 12 + chunk.length
        chunk
      end
      reader = create_mock_reader(chunks, signature)
      orchestrator = described_class.new(reader, "x")
      [orchestrator.validate.validation_result, orchestrator]
    end

    def ids(result) = result.errors.map(&:requirement_id)

    def structural(result)
      result.errors.map(&:requirement_id).grep(/\A(png|mng|jng|all)\.(IHDR|IEND|IDAT|MHDR|MEND|JHDR|JDAT|signature)\./)
    end

    # The mock IHDR/MHDR/JHDR chunks have placeholder bodies, so only the
    # top-level sequence IDs are compared.
    def sequence_ids(result)
      structural(result).grep(/\.(missing|first-chunk|last-chunk|unknown)\z/)
    end

    it "selects each exact signature and records the detected format" do
      { png_sig => ["PNG", %w[IHDR IDAT IEND]], mng_sig => ["MNG", %w[MHDR MEND]],
        jng_sig => ["JNG", %w[JHDR JDAT IEND]] }.each do |sig, (name, types)|
        result, orchestrator = run(sig, types)
        expect(orchestrator.detected_format.name).to eq(name)
        expect(result.file_type).to eq(name)
        expect(sequence_ids(result)).to be_empty
      end
    end

    it "gives an unknown signature its own diagnostic and no required-chunk findings" do
      result, orchestrator = run("GIF89a\x00\x00".b, %w[IEND])
      expect(orchestrator.detected_format).to be_nil
      expect(result.file_type).to eq("UNKNOWN")
      expect(sequence_ids(result)).to eq(["all.signature.unknown"])
      finding = result.errors.find { |e| e.requirement_id == "all.signature.unknown" }
      expect(finding).to have_attributes(severity: "error", chunk_type: "SIGNATURE",
                                         chunk_offset: 0, actual: "47 49 46 38 39 61 00 00")
      expect(finding.citation_label).to include("section 5.2")
    end

    {
      "PNG" => [
        [%w[IDAT IEND], "png.IHDR.missing"],
        [%w[IDAT IHDR IEND], "png.IHDR.first-chunk"],
        [%w[IHDR IDAT], "png.IEND.missing"],
        [%w[IHDR IEND IDAT], "png.IEND.last-chunk"],
        [%w[IHDR IEND], "png.IDAT.missing"],
      ],
      "MNG" => [
        [%w[MEND], "mng.MHDR.missing"],
        [%w[TERM MHDR MEND], "mng.MHDR.first-chunk"],
        [%w[MHDR], "mng.MEND.missing"],
        [%w[MHDR MEND TERM], "mng.MEND.last-chunk"],
      ],
      "JNG" => [
        [%w[JDAT IEND], "jng.JHDR.missing"],
        [%w[JDAT JHDR IEND], "jng.JHDR.first-chunk"],
        [%w[JHDR JDAT], "jng.IEND.missing"],
        [%w[JHDR IEND JDAT], "jng.IEND.last-chunk"],
        [%w[JHDR IEND], "jng.JDAT.missing"],
      ],
    }.each do |name, cases|
      cases.each do |types, id|
        it "reports #{id} for #{name} #{types.join(' ')} and nothing cross-format" do
          sig = { "PNG" => png_sig, "MNG" => mng_sig, "JNG" => jng_sig }.fetch(name)
          result, = run(sig, types)
          own = sequence_ids(result).select { |i| i.start_with?("#{name.downcase}.") }
          expect(own).to include(id)
          expect(sequence_ids(result) - own).to be_empty
        end
      end
    end

    it "does not demand PNG chunks of a valid MNG or JNG stream" do
      [[mng_sig, %w[MHDR MEND]], [jng_sig, %w[JHDR JDAT IEND]]].each do |sig, types|
        result, = run(sig, types)
        expect(ids(result).grep(/\Apng\.(IHDR|IEND|IDAT)\./)).to be_empty
      end
    end

    it "locates a misplaced terminator at the chunk and a missing one by type only" do
      result, = run(png_sig, %w[IHDR IEND IDAT])
      moved = result.errors.find { |e| e.requirement_id == "png.IEND.last-chunk" }
      expect(moved).to have_attributes(chunk_type: "IEND", chunk_index: 1, severity: "error")
      expect(moved.chunk_offset).to eq(8 + 12 + 0)
      expect(moved.citation_label).to include("5.6")

      result, = run(png_sig, %w[IHDR IDAT])
      missing = result.errors.find { |e| e.requirement_id == "png.IEND.missing" }
      expect(missing).to have_attributes(chunk_type: "IEND", chunk_offset: nil)
    end
  end

  # Helper to create a mock reader
  def create_mock_reader(chunks, signature = [137, 80, 78, 71, 13, 10, 26, 10].pack("C*"))
    reader = double("Reader")
    allow(reader).to receive(:each_chunk) do |&block|
      chunks.each(&block)
    end
    allow(reader).to receive_messages(signature: signature, file_size: 1000)
    reader
  end

  # Helper to create a BinData chunk-like object
  def create_bindata_chunk(type, offset, length)
    require "zlib"

    # Create mock data based on chunk type
    data = case type
           when "IHDR"
             # Valid IHDR: width(4) height(4) bit_depth(1) color_type(1) compression(1) filter(1) interlace(1)
             # 32x32, 8-bit, RGB (color type 2), no interlace
             [32, 32, 8, 2, 0, 0, 0].pack("NNC5")
           when "IEND"
             "" # IEND has no data
           else
             "\x00" * length
           end

    # Calculate CRC (chunk_type + data)
    crc = Zlib.crc32(type + data)

    # Create a double that mimics BinData chunk structure
    chunk = double("BinDataChunk")
    allow(chunk).to receive_messages(chunk_type: type, type: type,
                                     length: length, data: data, chunk_data: data, crc: crc, abs_offset: offset, crc_valid?: true)

    chunk
  end
end
