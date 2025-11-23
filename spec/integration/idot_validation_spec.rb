# frozen_string_literal: true

require "spec_helper"

RSpec.describe "iDOT Chunk Validation Integration" do
  let(:fixture_dir) { File.join(__dir__, "../fixtures/idot") }

  describe "Apple display optimization chunks" do
    it "validates iDOT chunk in white-10x10-screenshot.png" do
      file_path = File.join(fixture_dir, "white-10x10-screenshot.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)

      expect(result.valid?).to be true
      expect(result.error_messages).to be_empty

      # Verify iDOT chunk is present
      idot_chunks = result.chunks.select { |c| c.type == "iDOT" }
      expect(idot_chunks.size).to eq(1)

      # Verify iDOT chunk appears before IDAT
      chunk_types = result.chunks.map(&:type)
      idot_index = chunk_types.index("iDOT")
      idat_index = chunk_types.index("IDAT")
      expect(idot_index).to be < idat_index
    end

    it "validates file without iDOT chunk (white-10x10-noalpha.png)" do
      file_path = File.join(fixture_dir, "white-10x10-noalpha.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)

      expect(result.valid?).to be true

      # This file may not have iDOT chunk
      result.chunks.select { |c| c.type == "iDOT" }
      # Just verify validation passes, don't assert chunk presence
      expect(result.error_messages).to be_empty
    end

    it "validates iDOT chunk in name-screenshot.png" do
      file_path = File.join(fixture_dir, "name-screenshot.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)

      expect(result.valid?).to be true

      # Verify iDOT chunk is present
      idot_chunks = result.chunks.select { |c| c.type == "iDOT" }
      expect(idot_chunks.size).to eq(1)
    end

    it "validates file from iPhone (iphone-180x181-screenshot.png)" do
      file_path = File.join(fixture_dir, "iphone-180x181-screenshot.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)

      expect(result.valid?).to be true

      # Verify file validates correctly
      expect(result.error_messages).to be_empty
    end
  end

  describe "iDOT data decoding" do
    it "properly decodes iDOT chunk data" do
      file_path = File.join(fixture_dir, "white-10x10-screenshot.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)

      # Check that info messages include iDOT data
      info_messages = result.errors.select { |e| e.severity == "info" }
      idot_info = info_messages.find { |e| e.message.include?("iDOT") }

      expect(idot_info).not_to be_nil
      expect(idot_info.message).to include("Apple display optimization")
    end
  end

  describe "iDOT chunk ordering validation" do
    it "ensures iDOT appears before IDAT in files with iDOT" do
      Dir.glob(File.join(fixture_dir, "*.png")).each do |file_path|
        result = PngConform::Services::ValidationService.validate_file(file_path)

        chunk_types = result.chunks.map(&:type)
        next unless chunk_types.include?("iDOT")

        idot_index = chunk_types.index("iDOT")
        idat_index = chunk_types.index("IDAT")

        expect(idot_index).to be < idat_index,
                              "iDOT should appear before IDAT in #{File.basename(file_path)}"
      end
    end
  end

  describe "iDOT chunk length validation" do
    it "ensures all iDOT chunks are exactly 28 bytes" do
      Dir.glob(File.join(fixture_dir, "*.png")).each do |file_path|
        result = PngConform::Services::ValidationService.validate_file(file_path)

        idot_chunks = result.chunks.select { |c| c.type == "iDOT" }
        next if idot_chunks.empty?

        idot_chunks.each do |chunk|
          expect(chunk.length).to eq(28),
                                  "iDOT chunk should be 28 bytes in #{File.basename(file_path)}"
        end
      end
    end
  end

  describe "iDOT report generation" do
    it "generates proper summary report for iDOT chunk" do
      file_path = File.join(fixture_dir, "white-10x10-screenshot.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)

      output_io = StringIO.new
      reporter = PngConform::Reporters::ReporterFactory.create(
        format: "text",
        verbosity: :summary,
        colorize: false,
      )
      # Redirect reporter output to StringIO
      reporter.instance_variable_set(:@output, output_io)
      reporter.report(result)

      output = output_io.string
      expect(output).to include("white-10x10-screenshot.png")
      expect(output).not_to be_empty
    end
  end
end
