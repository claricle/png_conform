#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "yaml"
require_relative "lib/benchmark_runner"

# Parse command-line options
options = {
  config_file: nil,
  pattern: nil,
  format: nil,
  output: nil,
  iterations: nil,
  warmup: nil,
  limit: nil,
  tools: [],
  verbose: true,
}

OptionParser.new do |opts|
  opts.banner = "Usage: run_benchmark.rb [options]"

  opts.separator ""
  opts.separator "Configuration:"

  opts.on("-c", "--config FILE", "Load configuration from YAML file") do |file|
    options[:config_file] = file
  end

  opts.separator ""
  opts.separator "File Selection:"

  opts.on("-p", "--pattern PATTERN",
          "File pattern (e.g., 'spec/fixtures/**/*.png')") do |pattern|
    options[:pattern] = pattern
  end

  opts.on("-l", "--limit N", Integer, "Limit number of files to test") do |n|
    options[:limit] = n
  end

  opts.separator ""
  opts.separator "Execution:"

  opts.on("-i", "--iterations N", Integer,
          "Number of iterations per file (default: 3)") do |n|
    options[:iterations] = n
  end

  opts.on("-w", "--warmup N", Integer,
          "Number of warmup runs (default: 1)") do |n|
    options[:warmup] = n
  end

  opts.on("-t", "--tool TOOL",
          "Enable specific tool (png_conform, pngcheck)") do |tool|
    options[:tools] << tool.to_sym
  end

  opts.separator ""
  opts.separator "Output:"

  opts.on("-f", "--format FORMAT",
          "Output format: text, json, csv, markdown (default: text)") do |format|
    options[:format] = format
  end

  opts.on("-o", "--output FILE",
          "Write report to file instead of stdout") do |file|
    options[:output] = file
  end

  opts.on("-q", "--quiet", "Suppress progress output") do
    options[:verbose] = false
  end

  opts.separator ""
  opts.separator "Other:"

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end

  opts.on("-v", "--version", "Show version") do
    puts "PNG Benchmark Runner v1.0.0"
    exit
  end
end.parse!

# Load configuration
config = {}

if options[:config_file]
  unless File.exist?(options[:config_file])
    puts "Error: Configuration file not found: #{options[:config_file]}"
    exit 1
  end

  config = YAML.load_file(options[:config_file], symbolize_names: true)
end

# Apply command-line overrides
if options[:pattern]
  config[:test_files] ||= {}
  config[:test_files][:pattern] = options[:pattern]
end

if options[:limit]
  config[:test_files] ||= {}
  config[:test_files][:limit] = options[:limit]
end

config[:iterations] = options[:iterations] if options[:iterations]
config[:warmup_runs] = options[:warmup] if options[:warmup]

if options[:format]
  config[:output] ||= {}
  config[:output][:format] = options[:format]
end

if options[:output]
  config[:output] ||= {}
  config[:output][:file] = options[:output]
end

config[:output] ||= {}
config[:output][:verbose] = options[:verbose]

# Configure tools if specified
if options[:tools].any?
  config[:tools] ||= {}

  # Disable all tools by default if specific tools are requested
  config[:tools][:png_conform] = { enabled: false, options: {} }
  config[:tools][:pngcheck] = { enabled: false, options: {} }

  # Enable requested tools
  options[:tools].each do |tool|
    if config[:tools].key?(tool)
      config[:tools][tool][:enabled] = true
    else
      puts "Warning: Unknown tool '#{tool}', ignoring"
    end
  end
end

# Run the benchmark
begin
  runner = BenchmarkRunner.new(config)
  runner.run

  exit 0
rescue StandardError => e
  puts "\nError: #{e.message}"
  puts e.backtrace.join("\n") if ENV["DEBUG"]
  exit 1
end
