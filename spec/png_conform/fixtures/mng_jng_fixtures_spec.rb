# frozen_string_literal: true

require "spec_helper"
require "yaml"
require "zlib"

RSpec.describe "MNG/JNG fixture set" do
  # rubocop:disable RSpec/LeakyLocalVariable -- data-driven example generation
  fixture_root = File.expand_path("../../fixtures", __dir__)
  formats = {
    "mng" => { sig: [0x8a, 0x4d, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].pack("C*"),
               first: "MHDR", last: "MEND" },
    "jng" => { sig: [0x8b, 0x4a, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].pack("C*"),
               first: "JHDR", last: "IEND" },
  }.freeze

  read_chunks = lambda do |bytes|
    pos = 8
    chunks = []
    while pos + 12 <= bytes.bytesize
      len = bytes.byteslice(pos, 4).unpack1("N")
      type = bytes.byteslice(pos + 4, 4)
      data = bytes.byteslice(pos + 8, len)
      crc = bytes.byteslice(pos + 8 + len, 4).unpack1("N")
      chunks << { type: type, crc_ok: Zlib.crc32(type + data) == crc }
      pos += 12 + len
    end
    chunks
  end

  formats.each do |fmt, spec|
    dir = File.join(fixture_root, fmt)
    meta = YAML.safe_load_file(File.join(dir, "fixtures.yml"))

    describe fmt.upcase do
      it "records source, license and format" do
        expect(meta.values_at("format", "source", "license")).to all(be_a(String))
        expect(meta["format"]).to eq(fmt.upcase)
      end

      it "lists exactly the files on disk, with both validity outcomes" do
        listed = meta["fixtures"].map { |f| f["file"] }.sort
        expect(listed).to eq(Dir.children(dir).grep(/\.#{fmt}\z/).sort)
        expect(meta["fixtures"].map { |f| f["expected_validity"] }.uniq.sort)
          .to eq(%w[invalid valid])
      end

      meta["fixtures"].each do |entry|
        it "#{entry['file']} matches its metadata" do
          bytes = File.binread(File.join(dir, entry["file"]))
          expect(bytes.byteslice(0, 8)).to eq(spec[:sig])
          chunks = read_chunks.call(bytes)
          if entry["expected_validity"] == "valid"
            expect(chunks.first[:type]).to eq(spec[:first])
            expect(chunks.last[:type]).to eq(spec[:last])
            expect(chunks).to all(include(crc_ok: true))
          else
            expect(entry["exercises"]).not_to be_empty
          end
        end
      end
    end
  end
  # rubocop:enable RSpec/LeakyLocalVariable
end
