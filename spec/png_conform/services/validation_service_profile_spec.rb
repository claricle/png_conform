require "spec_helper"

require "png_conform/services/validation_service"

RSpec.describe PngConform::Services::ValidationService do
  let(:fixture) do
    File.expand_path("../../fixtures/pngsuite/basic/non_interlaced/basn0g01.png",
                     __dir__)
  end

  def validate_with(options)
    reader = PngConform::Readers::FullLoadReader.new(fixture)
    service = described_class.new(reader, fixture, options)
    analysis = service.validate
    [analysis, service.context.all_errors.map(&:requirement_id)]
  end

  it "applies no chunk policy without a profile" do
    analysis, ids = validate_with({})

    expect(analysis.valid?).to be(true)
    expect(ids).not_to include("profile.file.required-missing",
                               "profile.file.prohibited-present")
  end

  it "treats the none descriptor as no enforcement" do
    analysis, ids = validate_with(profile: "none")

    expect(analysis.valid?).to be(true)
    expect(ids).not_to include("profile.file.required-missing",
                               "profile.file.prohibited-present")
  end

  it "passes a conforming file under a named profile" do
    # basn0g01 carries IHDR, gAMA, IDAT, IEND: the web profile's required
    # chunks are present and none of its prohibited chunks appear.
    analysis, ids = validate_with(profile: "web")

    expect(analysis.valid?).to be(true)
    expect(ids).not_to include("profile.file.required-missing",
                               "profile.file.prohibited-present")
  end

  it "flags a missing required chunk for a named profile" do
    analysis, ids = validate_with(profile: "archive")

    expect(ids).to include("profile.file.required-missing")
    expect(analysis.valid?).to be(false)
  end

  it "flags a prohibited chunk present for an inline definition" do
    analysis, ids = validate_with(profile: { "prohibited_chunks" => ["gAMA"] })

    expect(ids).to include("profile.file.prohibited-present")
    expect(analysis.valid?).to be(false)
  end

  it "enforces an inline definition with symbol keys" do
    analysis, ids = validate_with(
      profile: { name: "custom", required_chunks: %w[IHDR IEND],
                 prohibited_chunks: [] },
    )

    expect(analysis.valid?).to be(true)
    expect(ids).not_to include("profile.file.required-missing")
  end

  it "raises for an unknown named profile" do
    reader = PngConform::Readers::FullLoadReader.new(fixture)
    service = described_class.new(reader, fixture, profile: "does-not-exist")

    expect { service.validate }
      .to raise_error(PngConform::UnknownProfileError)
  end
end
