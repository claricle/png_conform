# frozen_string_literal: true

require_relative "lib/png_conform/version"

Gem::Specification.new do |spec|
  spec.name = "png_conform"
  spec.version = PngConform::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Pure Ruby PNG/MNG/JNG validity checker with profile support"
  spec.description = <<~HEREDOC
    PngConform provides a comprehensive PNG, MNG, and JNG file validation library
    in pure Ruby. It validates file structure, chunk validity, CRC checksums,
    zlib compression, and profile conformance. Built with a layered architecture
    using BinData for binary parsing, Lutaml::Model for domain models, and Thor
    for CLI. Supports PNG baseline, MNG-VLC, MNG-LC, and JNG profiles with
    detailed validation reporting compatible with pngcheck output.
  HEREDOC

  spec.homepage = "https://github.com/claricle/png_conform"
  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/claricle/png_conform"
  spec.metadata["changelog_uri"] = "https://github.com/claricle/png_conform"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "bindata", "~> 2.5"
  spec.add_dependency "lutaml-model", "~> 0.7"
  spec.add_dependency "thor", "~> 1.4"
end
