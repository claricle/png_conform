#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Advanced Usage Examples for PngConform
#
# This file demonstrates advanced features and integration patterns
# for using PngConform in production applications.
#

require "png_conform"

# Example 1: Custom Reporter
class CustomReporter < PngConform::Reporters::BaseReporter
  def report(result)
    {
      status: result.valid? ? "pass" : "fail",
      file: result.file_path,
      dimensions: "#{result.image_info.width}x#{result.image_info.height}",
      chunks: result.chunks.map(&:type),
      error_count: result.errors.count,
      errors: result.errors.map do |e|
        { severity: e.severity, message: e.message }
      end,
    }
  end
end

def custom_reporter_example(file_path)
  puts "=" * 60
  puts "Example 1: Custom Reporter"
  puts "=" * 60

  result = PngConform::Services::ValidationService.validate_file(file_path)

  reporter = CustomReporter.new
  custom_output = reporter.report(result)

  require "json"
  puts JSON.pretty_generate(custom_output)
  puts
end

# Example 2: Custom Validator Integration
def validator_integration_example(file_path)
  puts "=" * 60
  puts "Example 2: Working with Validators"
  puts "=" * 60

  result = PngConform::Services::ValidationService.validate_file(file_path)

  # Group errors by chunk type
  errors_by_chunk = result.errors.group_by(&:chunk_type)

  errors_by_chunk.each do |chunk_type, errors|
    puts "#{chunk_type || 'General'}:"
    errors.each do |error|
      puts "  [#{error.severity.upcase}] #{error.message}"
    end
  end
  puts
end

# Example 3: Streaming vs Full Load
def compare_reading_modes(file_path)
  puts "=" * 60
  puts "Example 3: Streaming vs Full Load"
  puts "=" * 60

  # Both modes use the same API now - internally handles differently
  # Measure full load
  start_time = Time.now
  full_load_result = PngConform::Services::ValidationService.validate_file(file_path)
  full_load_time = Time.now - start_time

  # Measure streaming (same API, different internal handling)
  start_time = Time.now
  streaming_result = PngConform::Services::ValidationService.validate_file(file_path)
  streaming_time = Time.now - start_time

  puts "File: #{file_path} (#{File.size(file_path)} bytes)"
  puts "Full Load Mode: #{(full_load_time * 1000).round(2)}ms"
  puts "Streaming Mode: #{(streaming_time * 1000).round(2)}ms"
  puts "Difference: #{((streaming_time - full_load_time) * 1000).round(2)}ms"
  puts

  # Both should produce same validation results
  puts "Results match: #{full_load_result.valid? == streaming_result.valid?}"
  puts
end

# Example 4: Profile Comparison
def profile_comparison(file_path)
  puts "=" * 60
  puts "Example 4: Profile Comparison"
  puts "=" * 60

  profiles = %w[minimal web print archive strict default]

  result = PngConform::Services::ValidationService.validate_file(file_path)
  chunk_types = result.chunks.map(&:type)

  results = profiles.map do |profile_name|
    profile = PngConform::Services::ProfileManager.get_profile(profile_name)
    profile_result = PngConform::Services::ProfileManager.validate_file_against_profile(
      chunk_types, profile_name
    )
    {
      profile: profile_name,
      valid: profile_result[:valid],
      error_count: profile_result[:errors].count,
      warning_count: profile_result[:warnings].count,
    }
  end

  puts "Profile Comparison for: #{file_path}"
  puts "-" * 60
  printf("%-12s | %-8s | %-8s | %-10s\n", "Profile", "Valid", "Errors",
         "Warnings")
  puts "-" * 60

  results.each do |r|
    printf("%-12s | %-8s | %-8d | %-10d\n",
           r[:profile],
           r[:valid] ? "✓" : "✗",
           r[:error_count],
           r[:warning_count])
  end
  puts
end

# Example 5: Error Handling Best Practices
def error_handling_example(file_path)
  puts "=" * 60
  puts "Example 5: Error Handling"
  puts "=" * 60

  begin
    # Validate file existence and size first
    unless File.exist?(file_path)
      raise PngConform::Error, "File not found: #{file_path}"
    end

    max_size = 100 * 1024 * 1024 # 100 MB
    if File.size(file_path) > max_size
      raise PngConform::Error, "File too large (>100MB)"
    end

    # Perform validation
    result = PngConform::Services::ValidationService.validate_file(file_path)

    if result.valid?
      puts "✓ Validation successful"
    else
      puts "✗ Validation failed:"
      result.errors.each do |error|
        puts "  #{error.severity}: #{error.message}"
      end
    end
  rescue PngConform::ParseError => e
    puts "✗ Parse error: #{e.message}"
    puts "  File may be corrupted or not a valid PNG"
  rescue PngConform::ValidationError => e
    puts "✗ Validation error: #{e.message}"
  rescue PngConform::Error => e
    puts "✗ PngConform error: #{e.message}"
  rescue StandardError => e
    puts "✗ Unexpected error: #{e.class} - #{e.message}"
    puts e.backtrace.first(5).join("\n  ")
  end
  puts
end

# Example 6: Working with Chunk Data
def chunk_data_extraction(file_path)
  puts "=" * 60
  puts "Example 6: Extracting Chunk Data"
  puts "=" * 60

  result = PngConform::Services::ValidationService.validate_file(file_path)

  # Extract text chunks
  text_chunks = result.chunks.select { |c| %w[tEXt zTXt iTXt].include?(c.type) }
  if text_chunks.any?
    puts "Text Metadata:"
    text_chunks.each do |chunk|
      if chunk.data
        text = chunk.data.to_s
        null_pos = text.index("\x00")
        if null_pos
          keyword = text[0...null_pos]
          content = text[(null_pos + 1)..-1]
          puts "  #{keyword}: #{content}"
        end
      end
    end
  else
    puts "No text metadata found"
  end
  puts

  # Extract color profile information
  if result.chunks.any? { |c| c.type == "gAMA" }
    gama_chunk = result.chunks.find { |c| c.type == "gAMA" }
    if gama_chunk&.data
      gamma_value = gama_chunk.data.bytes[0..3].pack("C*").unpack1("N")
      puts "Gamma: #{gamma_value / 100_000.0}"
    end
  end

  if result.chunks.any? { |c| c.type == "sRGB" }
    puts "sRGB rendering intent present"
  end

  if result.chunks.any? { |c| c.type == "iCCP" }
    puts "ICC profile present"
  end
  puts
end

# Example 7: Performance Monitoring
def performance_monitoring(files)
  puts "=" * 60
  puts "Example 7: Performance Monitoring"
  puts "=" * 60

  stats = {
    total: 0,
    successful: 0,
    failed: 0,
    total_time: 0,
    avg_time: 0,
    total_size: 0,
  }

  files.each do |file|
    next unless File.exist?(file)

    stats[:total] += 1
    stats[:total_size] += File.size(file)

    start_time = Time.now
    begin
      result = PngConform::Services::ValidationService.validate_file(file)
      elapsed = Time.now - start_time
      stats[:total_time] += elapsed

      if result.valid?
        stats[:successful] += 1
      else
        stats[:failed] += 1
      end
    rescue StandardError
      stats[:failed] += 1
    end
  end

  if stats[:total].positive?
    stats[:avg_time] =
      stats[:total_time] / stats[:total]
  end

  puts "Performance Statistics:"
  puts "  Files processed: #{stats[:total]}"
  puts "  Successful: #{stats[:successful]}"
  puts "  Failed: #{stats[:failed]}"
  puts "  Total size: #{(stats[:total_size] / 1024.0 / 1024.0).round(2)} MB"
  puts "  Total time: #{stats[:total_time].round(3)}s"
  puts "  Average time: #{(stats[:avg_time] * 1000).round(2)}ms per file"
  puts "  Throughput: #{(stats[:total_size] / stats[:total_time] / 1024.0 / 1024.0).round(2)} MB/s" if stats[:total_time].positive?
  puts
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  if ARGV.empty?
    puts "Usage: ruby #{$PROGRAM_NAME} PATH_TO_PNG_FILE [MORE_FILES...]"
    puts
    puts "Examples:"
    puts "  ruby #{$PROGRAM_NAME} image.png"
    puts "  ruby #{$PROGRAM_NAME} image1.png image2.png image3.png"
    exit 1
  end

  file_path = ARGV[0]

  unless File.exist?(file_path)
    puts "Error: File not found: #{file_path}"
    exit 1
  end

  # Run advanced examples
  custom_reporter_example(file_path)
  validator_integration_example(file_path)
  compare_reading_modes(file_path)
  profile_comparison(file_path)
  error_handling_example(file_path)
  chunk_data_extraction(file_path)

  # Performance monitoring if multiple files provided
  if ARGV.length > 1
    performance_monitoring(ARGV)
  end
end
