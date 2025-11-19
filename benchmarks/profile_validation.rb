#!/usr/bin/env ruby
# frozen_string_literal: true

require "ruby-prof"
require_relative "../lib/png_conform"

# Pre-load everything
PngConform::Services::ValidationService

# Now profile just the validation work
file = ARGV[0] || "spec/fixtures/pngsuite/compression/z00n2c08.png"

result = RubyProf.profile do
  PngConform::Services::ValidationService.validate_file(file)
end

printer = RubyProf::FlatPrinter.new(result)
printer.print($stdout, min_percent: 1)
