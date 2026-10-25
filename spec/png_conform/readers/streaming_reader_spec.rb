# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Readers::StreamingReader do
  it "retains each chunk's file offset after reading and rewinding" do
    path = "spec/fixtures/pngsuite/corrupted/xhdn0g08.png"
    described_class.open(path) do |reader|
      2.times do
        chunks = reader.read_all_chunks
        expect(chunks.map(&:abs_offset)).to eq([8, 33, 49, 126])
        reader.rewind
        reader.read_signature
      end
    end
  end
end
