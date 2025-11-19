#!/usr/bin/env ruby
# frozen_string_literal: true

require "ruby-prof"

# Profile just the loading of png_conform
result = RubyProf::Profile.profile do
  require_relative "../lib/png_conform"
end

printer = RubyProf::FlatPrinter.new(result)
printer.print($stdout, min_percent: 2)
