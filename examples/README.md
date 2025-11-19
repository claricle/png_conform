# PngConform Examples

This directory contains example scripts demonstrating how to use PngConform in various scenarios.

## Quick Start

All examples are executable Ruby scripts. Make sure you have PngConform installed:

```bash
gem install png_conform
# or
bundle install
```

## Available Examples

### Basic Usage ([`basic_usage.rb`](basic_usage.rb))

Demonstrates fundamental PngConform operations:

- Basic file validation
- Profile-based validation
- Detailed chunk inspection
- Batch validation of multiple files
- Exporting results to YAML/JSON

**Run it:**
```bash
ruby examples/basic_usage.rb path/to/image.png
ruby examples/basic_usage.rb path/to/image.png path/to/png_directory
```

**What you'll learn:**
- How to validate a single PNG file
- How to use different validation profiles
- How to inspect chunk data
- How to process multiple files efficiently
- How to export validation results

### Advanced Usage ([`advanced_usage.rb`](advanced_usage.rb))

Demonstrates advanced integration patterns:

- Creating custom reporters
- Working with validators directly
- Comparing streaming vs full-load modes
- Profile comparison across all profiles
- Error handling best practices
- Extracting metadata from chunks
- Performance monitoring

**Run it:**
```bash
ruby examples/advanced_usage.rb path/to/image.png
ruby examples/advanced_usage.rb file1.png file2.png file3.png
```

**What you'll learn:**
- How to create custom output formats
- How to handle errors properly
- How to optimize for large files
- How to extract chunk metadata
- How to monitor performance

## Common Use Cases

### Validate a Single File

```ruby
require "png_conform"

service = PngConform::Services::ValidationService.new
result = service.validate_file("image.png")

puts result.valid? ? "Valid PNG" : "Invalid PNG"
```

### Batch Validation

```ruby
Dir.glob("images/*.png").each do |file|
  result = service.validate_file(file)
  puts "#{file}: #{result.valid? ? '✓' : '✗'}"
end
```

### Profile Validation

```ruby
profile_manager = PngConform::Services::ProfileManager.new
profile = profile_manager.load_profile("web")

result = service.validate_file("image.png", profile: profile)
```

### Extract Metadata

```ruby
result = service.validate_file("image.png")

# Get image dimensions
puts "#{result.image_info.width}x#{result.image_info.height}"

# Get chunk information
result.chunks.each do |chunk|
  puts "#{chunk.type}: #{chunk.length} bytes"
end
```

### Handle Errors

```ruby
begin
  result = service.validate_file("image.png")
rescue PngConform::ParseError => e
  puts "File is corrupted: #{e.message}"
rescue PngConform::Error => e
  puts "Validation error: #{e.message}"
end
```

## Testing the Examples

You can test the examples with files from the PngSuite test fixture:

```bash
# Using a test fixture
ruby examples/basic_usage.rb spec/fixtures/pngsuite/background/bgwn6a08.png

# Using multiple test files
ruby examples/advanced_usage.rb spec/fixtures/pngsuite/background/*.png
```

## Integration Patterns

### Web Application

```ruby
# In a Rails/Sinatra controller
def validate_upload
  uploaded_file = params[:file]

  # Save to temporary location
  temp_path = "/tmp/#{SecureRandom.hex}.png"
  File.write(temp_path, uploaded_file.read)

  # Validate
  service = PngConform::Services::ValidationService.new
  result = service.validate_file(temp_path)

  # Clean up
  File.delete(temp_path)

  # Return result
  render json: {
    valid: result.valid?,
    errors: result.errors.map(&:message)
  }
end
```

### Background Job

```ruby
# In a Sidekiq/ActiveJob worker
class PngValidationJob < ApplicationJob
  def perform(file_path)
    service = PngConform::Services::ValidationService.new
    result = service.validate_file(file_path, streaming: true)

    if result.valid?
      # Process valid file
      ProcessImageJob.perform_later(file_path)
    else
      # Handle invalid file
      NotifyUserJob.perform_later(user_id, result.errors)
    end
  end
end
```

### Command Line Tool

```ruby
#!/usr/bin/env ruby
# Custom validation script

require "png_conform"

ARGV.each do |file|
  service = PngConform::Services::ValidationService.new
  result = service.validate_file(file)

  status = result.valid? ? "PASS" : "FAIL"
  puts "#{status}: #{file}"

  unless result.valid?
    result.errors.each do |error|
      puts "  #{error.severity}: #{error.message}"
    end
  end
end
```

## Performance Tips

### Large Files

For files larger than 50MB, use streaming mode:

```ruby
result = service.validate_file("large.png", streaming: true)
```

### Batch Processing

Process files in parallel using threads:

```ruby
require "concurrent"

files = Dir.glob("images/*.png")
pool = Concurrent::FixedThreadPool.new(4)

files.each do |file|
  pool.post do
    result = service.validate_file(file)
    # Process result...
  end
end

pool.shutdown
pool.wait_for_termination
```

### Memory Management

For production systems, set resource limits:

```ruby
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100 MB
MAX_PROCESSING_TIME = 30  # seconds

if File.size(file_path) > MAX_FILE_SIZE
  raise "File too large"
end

Timeout.timeout(MAX_PROCESSING_TIME) do
  result = service.validate_file(file_path)
end
```

## Troubleshooting

### Common Issues

**"File not found" error:**
- Check file path is correct
- Use absolute paths if relative paths don't work
- Ensure file has read permissions

**Memory issues with large files:**
- Use streaming mode: `streaming: true`
- Process files one at a time
- Set memory limits in your environment

**Slow validation:**
- Use streaming mode for large files
- Consider caching results
- Run validation in background jobs

## Additional Resources

- [API Documentation](../README.adoc)
- [Architecture Guide](../ARCHITECTURE.md)
- [Contributing Guide](../CONTRIBUTING.md)
- [Security Policy](../SECURITY.md)

## Questions?

- Open an issue: https://github.com/claricle/png_conform/issues
- Read the documentation: https://github.com/claricle/png_conform