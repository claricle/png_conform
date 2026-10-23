# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Services::ChunkProcessor do
  let(:context) { PngConform::Validators::ValidationContext.new }
  let(:reader) { double("reader") }

  def chunk(type, offset)
    double("chunk", chunk_type: type, abs_offset: offset)
  end

  def process(chunks, options = {})
    allow(reader).to receive(:each_chunk) { |&blk| chunks.each(&blk) }
    described_class.new(reader, context, options).process
  end

  [{ batch_enabled: true }, { batch_enabled: false }].each do |options|
    context "with #{options}" do
      it "reports an unknown critical chunk as a cataloged error" do
        process([chunk("ABCD", 41)], options)

        expect(context.all_errors.size).to eq(1)
        expect(context.all_errors.first).to have_attributes(
          requirement_id: "png.chunk.unknown-critical", severity: "error",
          message: "Unknown critical chunk type: ABCD", chunk_type: "ABCD",
          chunk_offset: 41, error_type: "presence", actual: "ABCD",
          citation_label: a_string_including("13.2")
        )
        expect(context.all_errors.first.to_lens_h["location"])
          .to include("byte_offset" => 41, "record_type" => "ABCD")
      end

      it "reports an unknown ancillary chunk as informational" do
        process([chunk("abcd", 57)], options)

        expect(context.all_info.size).to eq(1)
        expect(context.all_info.first).to have_attributes(
          requirement_id: "info.png.chunk.unknown-ancillary", severity: "info",
          message: "Unknown ancillary chunk type: abcd (ignored)",
          chunk_type: "abcd", chunk_offset: 57, citation_uri: nil
        )
        expect(context.all_errors).to be_empty
      end
    end
  end
end
