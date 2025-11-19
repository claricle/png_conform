#!/usr/bin/env ruby
# frozen_string_literal: true

# Measure baseline Ruby performance without CLI overhead
require_relative "../lib/png_conform"

file = ARGV[0] || "spec/fixtures/pngsuite/compression/z00n2c08.png"

start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

result = PngConform::Services::ValidationService.validate_file(file,
                                                               quiet: true)

elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

puts "File: #{file}"
puts "Valid: #{result.valid?}"
puts "Time: #{(elapsed * 1000).round(1)}ms"
