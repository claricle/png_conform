# frozen_string_literal: true

require "spec_helper"

RSpec.describe "PNG Validation Integration" do
  let(:fixture_dir) { File.join(__dir__, "../fixtures/pngsuite") }

  describe "valid PNG files" do
    it "validates basic grayscale image" do
      skip "PngSuite fixtures not available" unless File.directory?(fixture_dir)

      file_path = File.join(fixture_dir, "basic/non_interlaced/basn0g01.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)
      expect(result.valid?).to be true
      expect(result.error_messages).to be_empty
    end

    it "validates basic RGB image" do
      skip "PngSuite fixtures not available" unless File.directory?(fixture_dir)

      file_path = File.join(fixture_dir, "basic/non_interlaced/basn2c08.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)
      expect(result.valid?).to be true
    end

    it "validates indexed color image" do
      skip "PngSuite fixtures not available" unless File.directory?(fixture_dir)

      file_path = File.join(fixture_dir, "basic/non_interlaced/basn3p08.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)
      expect(result.valid?).to be true
    end
  end

  describe "chunk validation" do
    it "detects CRC errors in chunks" do
      skip "PngSuite fixtures not available" unless File.directory?(fixture_dir)

      file_path = File.join(fixture_dir, "corrupted/xhdn0g08.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)
      expect(result.valid?).to be false
      expect(result.error_messages.any? do |e|
        e.message.include?("CRC")
      end).to be true
    end

    it "validates chunk ordering in interlaced images" do
      skip "PngSuite fixtures not available" unless File.directory?(fixture_dir)

      file_path = File.join(fixture_dir, "ordering/oi1n0g16.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)
      expect(result.valid?).to be true
    end

    it "detects invalid chunk data" do
      skip "PngSuite fixtures not available" unless File.directory?(fixture_dir)

      file_path = File.join(fixture_dir, "corrupted/xcsn0g01.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)
      expect(result.valid?).to be false
      expect(result.error_count).to be > 0
    end
  end

  describe "profile validation" do
    it "validates against web profile" do
      skip "PngSuite fixtures not available" unless File.directory?(fixture_dir)

      file_path = File.join(fixture_dir, "basic/non_interlaced/basn2c08.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)
      chunk_types = result.chunks.map(&:type).uniq

      profile_result = PngConform::Services::ProfileManager
        .validate_file_against_profile(chunk_types, :web)

      expect(profile_result[:valid]).to be true
      expect(profile_result[:errors]).to be_empty
    end

    it "validates against strict profile" do
      skip "PngSuite fixtures not available" unless File.directory?(fixture_dir)

      file_path = File.join(fixture_dir, "basic/non_interlaced/basn0g01.png")

      result = PngConform::Services::ValidationService.validate_file(file_path)
      chunk_types = result.chunks.map(&:type).uniq

      profile_result = PngConform::Services::ProfileManager
        .validate_file_against_profile(chunk_types, :strict)

      expect(profile_result[:valid]).to be true
      expect(profile_result[:errors]).to be_empty
    end
  end

  describe "end-to-end validation workflow" do
    it "validates file and generates report" do
      skip "PngSuite fixtures not available" unless File.directory?(fixture_dir)

      file_path = File.join(fixture_dir, "basic/non_interlaced/basn2c08.png")

      # Validate file
      result = PngConform::Services::ValidationService.validate_file(file_path)

      # Generate report with captured output
      output_io = StringIO.new
      reporter = PngConform::Reporters::SummaryReporter.new(output_io)
      reporter.report(result)

      output = output_io.string
      expect(output).to include("basn2c08.png")
      expect(output).not_to be_empty
    end
  end

  private

  def capture_output
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end
