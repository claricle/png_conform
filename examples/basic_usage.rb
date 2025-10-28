#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Basic Usage Examples for PngConform
#
# This file demonstrates the most common ways to use PngConform
# for validating PNG files programmatically.
#

require "png_conform"

# Example 1: Basic validation
def basic_validation(file_path)
  puts "=" * 60
  puts "Example 1: Basic Validation"
  puts "=" * 60

  service = PngConform::Services::ValidationService.new
  result = service.validate_file(file_path)

  if result.valid?
    puts "✓ File is valid!"
    puts "  Dimensions: #{result.image_info.width}x#{result.image_info.height}"
    puts "  Color type: #{result.image_info.color_type_name}"
    puts "  Bit depth: #{result.image_info.bit_depth}"
    puts "  Chunks: #{result.chunks.count}"
  else
    puts "✗ File has errors:"
    result.errors.each do |error|
      puts "  #{error.severity.upcase}: #{error.message}"
    end
  end
  puts
end

# Example 2: Validation with specific profile
def profile_validation(file_path, profile_name)
  puts "=" * 60
  puts "Example 2: Profile-Based Validation (#{profile_name})"
  puts "=" * 60

  profile_manager = PngConform::Services::ProfileManager.new
  profile = profile_manager.load_profile(profile_name)

  service = PngConform::Services::ValidationService.new
  result = service.validate_file(file_path, profile: profile)

  puts "Profile: #{profile.name} - #{profile.description}"
  puts "Required chunks: #{profile.required_chunks.join(', ')}"
  puts

  profile_errors = result.errors.select { |e| e.message.include?("profile") }
  if profile_errors.empty?
    puts "✓ File conforms to #{profile_name} profile"
  else
    puts "✗ Profile violations:"
    profile_errors.each do |error|
      puts "  #{error.message}"
    end
  end
  puts
end

# Example 3: Detailed chunk inspection
def inspect_chunks(file_path)
  puts "=" * 60
  puts "Example 3: Detailed Chunk Inspection"
  puts "=" * 60

  service = PngConform::Services::ValidationService.new
  result = service.validate_file(file_path)

  puts "File: #{file_path}"
  puts "Chunks found: #{result.chunks.count}"
  puts

  result.chunks.each do |chunk|
    puts "Chunk: #{chunk.type}"
    puts "  Offset: 0x#{chunk.offset.to_s(16).rjust(8, '0')}"
    puts "  Length: #{chunk.length} bytes"
    puts "  CRC: 0x#{chunk.crc.to_s(16).upcase.rjust(8, '0')}"
    puts "  CRC Valid: #{chunk.crc_valid? ? '✓' : '✗'}"

    # Display decoded data for specific chunks
    if chunk.decoded_data
      case chunk.type
      when "IHDR"
        data = chunk.decoded_data
        puts "  Width: #{data.width}"
        puts "  Height: #{data.height}"
        puts "  Color Type: #{data.color_type_name}"
      when "gAMA"
        puts "  Gamma: #{chunk.decoded_data.gamma}"
      when "tEXt"
        puts "  Keyword: #{chunk.decoded_data.keyword}"
        puts "  Text: #{chunk.decoded_data.text[0..50]}..."
      end
    end
    puts
  end
end

# Example 4: Batch validation
def batch_validation(directory)
  puts "=" * 60
  puts "Example 4: Batch Validation"
  puts "=" * 60

  service = PngConform::Services::ValidationService.new
  results = {
    valid: [],
    invalid: [],
    errors: [],
  }

  Dir.glob(File.join(directory, "*.png")).each do |file|
    result = service.validate_file(file)
    if result.valid?
      results[:valid] << file
    else
      results[:invalid] << { file: file, errors: result.errors }
    end
  rescue StandardError => e
    results[:errors] << { file: file, error: e.message }
  end

  puts "Processed #{results[:valid].count + results[:invalid].count + results[:errors].count} files"
  puts "  Valid: #{results[:valid].count}"
  puts "  Invalid: #{results[:invalid].count}"
  puts "  Errors: #{results[:errors].count}"
  puts

  unless results[:invalid].empty?
    puts "Invalid files:"
    results[:invalid].each do |item|
      puts "  #{File.basename(item[:file])}: #{item[:errors].count} errors"
    end
  end
  puts
end

# Example 5: Export validation results
def export_results(file_path, format = :yaml)
  puts "=" * 60
  puts "Example 5: Export Results (#{format.upcase})"
  puts "=" * 60

  service = PngConform::Services::ValidationService.new
  result = service.validate_file(file_path)

  case format
  when :yaml
    require "yaml"
    puts result.to_yaml
  when :json
    require "json"
    puts JSON.pretty_generate(result.to_h)
  else
    puts "Unknown format: #{format}"
  end
  puts
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  # Check if a file path was provided
  if ARGV.empty?
    puts "Usage: ruby #{$PROGRAM_NAME} PATH_TO_PNG_FILE [DIRECTORY_FOR_BATCH]"
    puts
    puts "Examples:"
    puts "  ruby #{$PROGRAM_NAME} image.png"
    puts "  ruby #{$PROGRAM_NAME} image.png ./png_directory"
    exit 1
  end

  file_path = ARGV[0]
  directory = ARGV[1]

  unless File.exist?(file_path)
    puts "Error: File not found: #{file_path}"
    exit 1
  end

  # Run examples
  basic_validation(file_path)
  profile_validation(file_path, "web")
  inspect_chunks(file_path)
  export_results(file_path, :yaml)

  # Run batch validation if directory provided
  if directory && Dir.exist?(directory)
    batch_validation(directory)
  end
end
