# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Services::ValidationService do
  describe "#validate" do
    context "with valid PNG structure" do
      let(:reader) { create_mock_reader(valid_chunks) }
      let(:service) { described_class.new(reader, "test.png") }

      let(:valid_chunks) do
        [
          create_bindata_chunk("IHDR", 0, 13),
          create_bindata_chunk("IDAT", 21, 100),
          create_bindata_chunk("IEND", 133, 0),
        ]
      end

      it "returns a validation result" do
        result = service.validate
        expect(result).to be_a(PngConform::Models::ValidationResult)
      end

      it "validates the PNG signature" do
        result = service.validate
        # Should not have signature errors for valid structure
        signature_errors = result.errors.select do |e|
          e.message.include?("signature")
        end
        expect(signature_errors).to be_empty
      end

      it "validates chunk sequence" do
        result = service.validate
        # IHDR first, IEND last, IDAT present - should be valid
        expect(result.error_count).to eq(0)
      end
    end

    context "with missing IHDR" do
      let(:reader) { create_mock_reader(chunks_without_ihdr) }
      let(:service) { described_class.new(reader, "test.png") }

      let(:chunks_without_ihdr) do
        [
          create_bindata_chunk("IDAT", 0, 100),
          create_bindata_chunk("IEND", 112, 0),
        ]
      end

      it "adds error for missing IHDR" do
        result = service.validate
        expect(result.error_count).to be > 0
        ihdr_errors = result.errors.select { |e| e.message.include?("IHDR") }
        expect(ihdr_errors).not_to be_empty
      end
    end

    context "with missing IEND" do
      let(:reader) { create_mock_reader(chunks_without_iend) }
      let(:service) { described_class.new(reader, "test.png") }

      let(:chunks_without_iend) do
        [
          create_bindata_chunk("IHDR", 0, 13),
          create_bindata_chunk("IDAT", 21, 100),
        ]
      end

      it "adds error for missing IEND" do
        result = service.validate
        expect(result.error_count).to be > 0
        iend_errors = result.errors.select { |e| e.message.include?("IEND") }
        expect(iend_errors).not_to be_empty
      end
    end

    context "with missing IDAT" do
      let(:reader) { create_mock_reader(chunks_without_idat) }
      let(:service) { described_class.new(reader, "test.png") }

      let(:chunks_without_idat) do
        [
          create_bindata_chunk("IHDR", 0, 13),
          create_bindata_chunk("IEND", 21, 0),
        ]
      end

      it "adds error for missing IDAT" do
        result = service.validate
        expect(result.error_count).to be > 0
        idat_errors = result.errors.select { |e| e.message.include?("IDAT") }
        expect(idat_errors).not_to be_empty
      end
    end

    context "with unknown critical chunk" do
      let(:reader) { create_mock_reader(chunks_with_unknown_critical) }
      let(:service) { described_class.new(reader, "test.png") }

      let(:chunks_with_unknown_critical) do
        [
          create_bindata_chunk("IHDR", 0, 13),
          create_bindata_chunk("ABCD", 21, 10), # Unknown critical (uppercase first letter)
          create_bindata_chunk("IDAT", 43, 100),
          create_bindata_chunk("IEND", 155, 0),
        ]
      end

      it "adds error for unknown critical chunk" do
        result = service.validate
        expect(result.error_count).to be > 0
        unknown_errors = result.errors.select do |e|
          e.message.include?("Unknown") && e.message.include?("critical")
        end
        expect(unknown_errors).not_to be_empty
      end
    end

    context "with unknown ancillary chunk" do
      let(:reader) { create_mock_reader(chunks_with_unknown_ancillary) }
      let(:service) { described_class.new(reader, "test.png") }

      let(:chunks_with_unknown_ancillary) do
        [
          create_bindata_chunk("IHDR", 0, 13),
          create_bindata_chunk("abcd", 21, 10), # Unknown ancillary (lowercase first letter)
          create_bindata_chunk("IDAT", 43, 100),
          create_bindata_chunk("IEND", 155, 0),
        ]
      end

      it "does not add error for unknown ancillary chunk" do
        result = service.validate
        # Unknown ancillary chunks are allowed per PNG spec
        # Check that there are no critical chunk errors
        unknown_critical_errors = result.errors.select do |e|
          e.message.include?("Unknown") && e.message.include?("critical")
        end
        expect(unknown_critical_errors).to be_empty
      end
    end
  end

  # Helper to create a mock reader
  def create_mock_reader(chunks)
    reader = double("Reader")
    allow(reader).to receive(:each_chunk) do |&block|
      chunks.each(&block)
    end
    allow(reader).to receive_messages(signature: [137, 80, 78, 71, 13, 10,
                                                  26, 10].pack("C*"), file_size: 1000)
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
