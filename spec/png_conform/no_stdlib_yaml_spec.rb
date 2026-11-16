# frozen_string_literal: true

RSpec.describe "YAML access in lib" do
  let(:sources) do
    Dir.glob("lib/**/*.rb", base: File.expand_path("../..", __dir__))
      .to_h { |f| [f, File.read(File.expand_path("../../#{f}", __dir__))] }
  end

  it "does not require the stdlib yaml" do
    offenders = sources.select { |_, src| src.match?(/^\s*require\s+["'](yaml|psych)["']/) }
    expect(offenders.keys).to be_empty
  end

  it "does not call stdlib YAML or Psych directly" do
    offenders = sources.select do |file, src|
      next false if file.end_with?("yaml_io.rb")

      src.gsub(/#.*$/, "").match?(/(?<![:\w])(YAML|Psych)\.|\.to_yaml/)
    end
    expect(offenders.keys).to be_empty
  end
end
