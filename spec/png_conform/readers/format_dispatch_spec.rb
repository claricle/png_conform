# frozen_string_literal: true

require "spec_helper"
require "stringio"
require_relative "../../support/format_file_builder"

RSpec.describe PngConform::Readers::FormatDispatch do
  let(:builder) { PngConform::Spec::FormatFileBuilder }
  let(:dispatch) { described_class }

  describe ".detect" do
    {
      "PNG" => [[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], :png, "IHDR", "IEND", "IDAT"],
      "MNG" => [[0x8A, 0x4D, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], :mng, "MHDR", "MEND", nil],
      "JNG" => [[0x8B, 0x4A, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], :jng, "JHDR", "IEND", "JDAT"],
    }.each do |name, (bytes, key, header, terminator, data)|
      it "maps the exact #{name} signature to its format rules" do
        format = dispatch.detect(bytes.pack("C*"))
        expect(format).to have_attributes(key: key, name: name, header: header,
                                          terminator: terminator, data_chunk: data)
      end
    end

    it "returns nil for an unknown signature" do
      expect(dispatch.detect(builder::UNKNOWN_SIG)).to be_nil
    end

    it "returns nil when a single signature byte differs or the signature is short" do
      near_png = builder::PNG_SIG.dup.tap { |s| s.setbyte(7, 0x0B) }
      expect(dispatch.detect(near_png)).to be_nil
      expect(dispatch.detect(builder::PNG_SIG[0, 7])).to be_nil
      expect(dispatch.detect(nil)).to be_nil
    end
  end

  describe PngConform::Readers::StreamingReader do
    def read_types(bytes)
      reader = described_class.new(StringIO.new(bytes))
      reader.read_signature
      [reader, reader.each_chunk.map(&:type)]
    end

    it "recognizes all three signatures and records the format" do
      { builder.valid_png => :png, builder.valid_mng => :mng, builder.valid_jng => :jng }.each do |bytes, key|
        reader, = read_types(bytes)
        expect(reader).to be_valid_signature
        expect(reader.format.key).to eq(key)
      end
    end

    it "rejects an unknown signature" do
      reader = described_class.new(StringIO.new(builder::UNKNOWN_SIG + builder.iend))
      expect(reader.read_signature).to be false
      expect(reader.format).to be_nil
    end

    it "reads a MNG through MEND, past an embedded IEND" do
      bytes = builder.mng(builder.mhdr, builder.ihdr, builder.idat, builder.iend, builder.mend)
      expect(read_types(bytes).last).to eq(%w[MHDR IHDR IDAT IEND MEND])
    end

    it "stops at the outer terminator of PNG and JNG" do
      expect(read_types(builder.png(builder.ihdr, builder.idat, builder.iend, builder.mend)).last)
        .to eq(%w[IHDR IDAT IEND])
      expect(read_types(builder.jng(builder.jhdr, builder.jdat, builder.iend, builder.mend)).last)
        .to eq(%w[JHDR JDAT IEND])
    end

    it "does not stop a MNG at an IEND when MEND follows later" do
      bytes = builder.mng(builder.mhdr, builder.iend, builder.chunk("TERM", "\x00".b * 10), builder.mend)
      expect(read_types(bytes).last).to eq(%w[MHDR IEND TERM MEND])
    end
  end

  describe PngConform::Readers::FullLoadReader do
    it "parses the generic chunk stream of all three formats" do
      cases = { builder.valid_png => [:png, %w[IHDR IDAT IEND]],
                builder.valid_mng => [:mng, %w[MHDR MEND]],
                builder.valid_jng => [:jng, %w[JHDR JDAT IEND]] }
      cases.each do |bytes, (key, types)|
        reader = described_class.new(StringIO.new(bytes))
        expect(reader.format.key).to eq(key)
        expect(reader.to_enum(:each_chunk).map(&:type)).to eq(types)
      end
    end

    it "reports no format for an unknown signature" do
      reader = described_class.new(StringIO.new(builder::UNKNOWN_SIG + builder.iend))
      expect(reader.format).to be_nil
    end
  end
end
