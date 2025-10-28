# frozen_string_literal: true

require "spec_helper"
require "png_conform/services/profile_manager"

RSpec.describe PngConform::Services::ProfileManager do
  describe ".available_profiles" do
    it "returns all profile names" do
      profiles = described_class.available_profiles
      expect(profiles).to include(:minimal, :web, :print, :archive, :strict,
                                  :default)
    end

    it "returns at least 6 profiles" do
      profiles = described_class.available_profiles
      expect(profiles.length).to be >= 6
    end
  end

  describe ".profile_exists?" do
    it "returns true for existing profiles" do
      expect(described_class.profile_exists?("minimal")).to be true
      expect(described_class.profile_exists?("web")).to be true
      expect(described_class.profile_exists?("print")).to be true
    end

    it "returns false for non-existent profiles" do
      expect(described_class.profile_exists?("nonexistent")).to be false
      expect(described_class.profile_exists?("invalid")).to be false
    end
  end

  describe ".get_profile" do
    context "with minimal profile" do
      it "returns the minimal profile" do
        profile = described_class.get_profile("minimal")
        expect(profile).to be_a(Hash)
        expect(profile[:required_chunks]).to include("IHDR", "IDAT", "IEND")
      end
    end

    context "with web profile" do
      it "prohibits color management chunks" do
        profile = described_class.get_profile("web")
        expect(profile[:prohibited_chunks]).to include("iCCP", "cHRM", "sBIT")
      end
    end

    context "with print profile" do
      it "requires physical dimensions" do
        profile = described_class.get_profile("print")
        expect(profile[:required_chunks]).to include("pHYs")
      end
    end

    context "with archive profile" do
      it "requires timestamp" do
        profile = described_class.get_profile("archive")
        expect(profile[:required_chunks]).to include("tIME")
      end
    end

    context "with strict profile" do
      it "allows all standard chunks" do
        profile = described_class.get_profile("strict")
        expect(profile[:optional_chunks]).to include("gAMA", "sRGB")
      end
    end

    context "with non-existent profile" do
      it "returns nil" do
        profile = described_class.get_profile("nonexistent")
        expect(profile).to be_nil
      end
    end
  end

  describe ".validate_chunk_against_profile" do
    it "returns success for allowed chunks" do
      result = described_class.validate_chunk_against_profile("IHDR", "web")
      expect(result[:status]).to eq(:success)
    end

    it "returns error for prohibited chunks" do
      result = described_class.validate_chunk_against_profile("iCCP", "web")
      expect(result[:status]).to eq(:error)
      expect(result[:message]).to include("prohibited")
    end
  end

  describe ".check_required_chunks" do
    let(:chunks) { %w[IHDR IDAT IEND] }

    it "returns empty array when all required chunks present" do
      missing = described_class.check_required_chunks(chunks, "minimal")
      expect(missing).to be_empty
    end

    it "returns missing chunk types for missing required chunks" do
      missing = described_class.check_required_chunks(%w[IHDR IEND],
                                                      "minimal")
      expect(missing).not_to be_empty
      expect(missing).to include("IDAT")
    end
  end

  describe ".check_prohibited_chunks" do
    it "returns empty array when no prohibited chunks present" do
      chunks = %w[IHDR IDAT IEND gAMA]
      prohibited = described_class.check_prohibited_chunks(chunks, "web")
      expect(prohibited).to be_empty
    end

    it "returns prohibited chunk types for prohibited chunks" do
      chunks = %w[IHDR iCCP IDAT IEND]
      prohibited = described_class.check_prohibited_chunks(chunks, "web")
      expect(prohibited).not_to be_empty
      expect(prohibited).to include("iCCP")
    end
  end

  describe ".validate_file_against_profile" do
    context "with minimal profile" do
      let(:chunks) { %w[IHDR IDAT IEND] }

      it "validates successfully" do
        result = described_class.validate_file_against_profile(chunks,
                                                               "minimal")
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end
    end

    context "with web profile and prohibited chunk" do
      let(:chunks) { %w[IHDR iCCP IDAT IEND] }

      it "returns errors for prohibited chunks" do
        result = described_class.validate_file_against_profile(chunks, "web")
        expect(result[:valid]).to be false
        expect(result[:errors]).not_to be_empty
        expect(result[:errors].first).to match(/prohibited/i)
      end
    end

    context "with print profile missing required chunk" do
      let(:chunks) { %w[IHDR IDAT IEND] }

      it "returns errors for missing required chunks" do
        result = described_class.validate_file_against_profile(chunks, "print")
        expect(result[:valid]).to be false
        expect(result[:errors]).not_to be_empty
        expect(result[:errors].first).to include("required")
        expect(result[:errors].first).to include("pHYs")
      end
    end
  end
end
