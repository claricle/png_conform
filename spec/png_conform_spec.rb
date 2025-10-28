# frozen_string_literal: true

RSpec.describe PngConform do
  it "has a version number" do
    expect(PngConform::VERSION).not_to be_nil
  end

  it "defines the main module" do
    expect(described_class).to be_a(Module)
  end

  it "defines Error classes" do
    expect(PngConform::Error).to be < StandardError
    expect(PngConform::ValidationError).to be < PngConform::Error
    expect(PngConform::ParseError).to be < PngConform::Error
  end
end
