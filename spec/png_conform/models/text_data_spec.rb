# frozen_string_literal: true

require "spec_helper"

RSpec.describe PngConform::Models::TextData do
  describe "#summary" do
    it "formats keyword and text" do
      data = described_class.new(keyword: "Author", text: "John Doe")
      expect(data.summary).to eq("Author: John Doe")
    end

    it "handles empty text" do
      data = described_class.new(keyword: "Comment", text: "")
      expect(data.summary).to eq("Comment: ")
    end
  end
end
