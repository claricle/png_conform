# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::FileInfo do
  describe "constants" do
    it "defines file type constants" do
      expect(described_class::FILE_TYPE_PNG).to eq("PNG")
      expect(described_class::FILE_TYPE_MNG).to eq("MNG")
      expect(described_class::FILE_TYPE_JNG).to eq("JNG")
      expect(described_class::FILE_TYPE_UNKNOWN).to eq("UNKNOWN")
    end

    it "defines color type constants" do
      expect(described_class::COLOR_TYPE_GRAYSCALE).to eq(0)
      expect(described_class::COLOR_TYPE_RGB).to eq(2)
      expect(described_class::COLOR_TYPE_INDEXED).to eq(3)
      expect(described_class::COLOR_TYPE_GRAYSCALE_ALPHA).to eq(4)
      expect(described_class::COLOR_TYPE_RGB_ALPHA).to eq(6)
    end
  end

  describe "#color_type_name" do
    it "returns 'grayscale' for color type 0" do
      info = described_class.new(color_type: 0)
      expect(info.color_type_name).to eq("grayscale")
    end

    it "returns 'RGB' for color type 2" do
      info = described_class.new(color_type: 2)
      expect(info.color_type_name).to eq("RGB")
    end

    it "returns 'indexed' for color type 3" do
      info = described_class.new(color_type: 3)
      expect(info.color_type_name).to eq("indexed")
    end

    it "returns 'grayscale+alpha' for color type 4" do
      info = described_class.new(color_type: 4)
      expect(info.color_type_name).to eq("grayscale+alpha")
    end

    it "returns 'RGB+alpha' for color type 6" do
      info = described_class.new(color_type: 6)
      expect(info.color_type_name).to eq("RGB+alpha")
    end

    it "returns 'unknown' for invalid color type" do
      info = described_class.new(color_type: 99)
      expect(info.color_type_name).to eq("unknown")
    end
  end

  describe "#interlace_method_name" do
    it "returns 'non-interlaced' for method 0" do
      info = described_class.new(interlace_method: 0)
      expect(info.interlace_method_name).to eq("non-interlaced")
    end

    it "returns 'Adam7 interlaced' for method 1" do
      info = described_class.new(interlace_method: 1)
      expect(info.interlace_method_name).to eq("Adam7 interlaced")
    end

    it "returns 'unknown' for invalid method" do
      info = described_class.new(interlace_method: 99)
      expect(info.interlace_method_name).to eq("unknown")
    end
  end

  describe "#interlaced?" do
    it "returns true when interlace_method is 1" do
      info = described_class.new(interlace_method: 1)
      expect(info.interlaced?).to be true
    end

    it "returns false when interlace_method is 0" do
      info = described_class.new(interlace_method: 0)
      expect(info.interlaced?).to be false
    end

    it "returns false for other interlace methods" do
      info = described_class.new(interlace_method: 99)
      expect(info.interlaced?).to be false
    end
  end

  describe "#dimensions" do
    it "formats dimensions as WxH" do
      info = described_class.new(width: 1920, height: 1080)
      expect(info.dimensions).to eq("1920x1080")
    end

    it "handles small dimensions" do
      info = described_class.new(width: 32, height: 32)
      expect(info.dimensions).to eq("32x32")
    end
  end

  describe "#bit_depth_description" do
    it "combines bit depth and color type" do
      info = described_class.new(bit_depth: 8, color_type: 2)
      expect(info.bit_depth_description).to eq("8-bit RGB")
    end

    it "handles different bit depths" do
      info = described_class.new(bit_depth: 16, color_type: 6)
      expect(info.bit_depth_description).to eq("16-bit RGB+alpha")
    end

    it "handles palette color type" do
      info = described_class.new(bit_depth: 4, color_type: 3)
      expect(info.bit_depth_description).to eq("4-bit indexed")
    end
  end

  describe "#signature_hex" do
    it "converts signature to hex string" do
      signature = "PNG\r\n\x1a\n"
      info = described_class.new(signature: signature)
      expect(info.signature_hex).to eq("504e470d0a1a0a")
    end

    it "returns nil when signature is nil" do
      info = described_class.new
      expect(info.signature_hex).to be_nil
    end
  end

  describe "#png?" do
    it "returns true for PNG file type" do
      info = described_class.new(file_type: "PNG")
      expect(info.png?).to be true
    end

    it "returns false for other file types" do
      info = described_class.new(file_type: "MNG")
      expect(info.png?).to be false
    end
  end

  describe "#mng?" do
    it "returns true for MNG file type" do
      info = described_class.new(file_type: "MNG")
      expect(info.mng?).to be true
    end

    it "returns false for other file types" do
      info = described_class.new(file_type: "PNG")
      expect(info.mng?).to be false
    end
  end

  describe "#jng?" do
    it "returns true for JNG file type" do
      info = described_class.new(file_type: "JNG")
      expect(info.jng?).to be true
    end

    it "returns false for other file types" do
      info = described_class.new(file_type: "PNG")
      expect(info.jng?).to be false
    end
  end

  describe "attribute initialization" do
    it "accepts basic attributes" do
      info = described_class.new(
        filename: "test.png",
        file_size: 2048,
        file_type: "PNG",
        signature: "PNG",
      )

      expect(info.filename).to eq("test.png")
      expect(info.file_size).to eq(2048)
      expect(info.file_type).to eq("PNG")
      expect(info.signature).to eq("PNG")
    end

    it "accepts image attributes" do
      info = described_class.new(
        width: 640,
        height: 480,
        bit_depth: 8,
        color_type: 2,
        compression_method: 0,
        filter_method: 0,
        interlace_method: 0,
      )

      expect(info.width).to eq(640)
      expect(info.height).to eq(480)
      expect(info.bit_depth).to eq(8)
      expect(info.color_type).to eq(2)
      expect(info.compression_method).to eq(0)
      expect(info.filter_method).to eq(0)
      expect(info.interlace_method).to eq(0)
    end
  end
end
