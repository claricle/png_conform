# Security Policy

## Supported Versions

We release patches for security vulnerabilities. Currently supported versions:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

## Reporting a Vulnerability

The PngConform team takes security bugs seriously. We appreciate your efforts to responsibly disclose your findings.

### How to Report

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to:

- **Email**: open.source@ribose.com
- **Subject**: [SECURITY] PngConform - Brief description

### What to Include

Please include the following information in your report:

1. **Type of issue** (e.g. buffer overflow, code injection, etc.)
2. **Full paths of source file(s)** related to the manifestation of the issue
3. **Location of the affected source code** (tag/branch/commit or direct URL)
4. **Step-by-step instructions** to reproduce the issue
5. **Proof-of-concept or exploit code** (if possible)
6. **Impact of the issue**, including how an attacker might exploit it

### What to Expect

You should receive a response within 48 hours. If for some reason you do not, please follow up via email to ensure we received your original message.

After the initial reply to your report, the security team will:

1. **Confirm the problem** and determine the affected versions
2. **Audit code** to find any similar problems
3. **Prepare fixes** for all supported versions
4. **Release patches** as soon as possible

### Disclosure Policy

- Security issues are disclosed publicly after a fix is released
- We ask that you give us a reasonable time to address the issue before making it public
- We will credit you in the disclosure (unless you prefer to remain anonymous)

## Security Best Practices

When using PngConform:

### File Input Validation

```ruby
# Always validate file existence and size before processing
if File.exist?(path) && File.size(path) < MAX_FILE_SIZE
  service = PngConform::Services::ValidationService.new
  result = service.validate_file(path)
else
  # Handle invalid file
end
```

### Resource Limits

```ruby
# For production use, consider setting resource limits
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100 MB
MAX_PROCESSING_TIME = 30  # seconds

# Use streaming mode for large files
service = PngConform::Services::ValidationService.new
result = service.validate_file(path, streaming: true)
```

### User Input Sanitization

```ruby
# When processing user-uploaded files
require 'securerandom'

def process_uploaded_file(uploaded_file)
  # Use secure temporary directory
  temp_dir = File.join(Dir.tmpdir, SecureRandom.hex)
  Dir.mkdir(temp_dir, 0700)

  temp_path = File.join(temp_dir, "temp.png")

  begin
    File.open(temp_path, 'wb') do |f|
      f.write(uploaded_file.read)
    end

    # Validate the file
    service = PngConform::Services::ValidationService.new
    result = service.validate_file(temp_path)

    # Process result...
  ensure
    # Clean up
    FileUtils.rm_rf(temp_dir)
  end
end
```

### Dependency Management

- Keep dependencies up to date: `bundle update`
- Regularly run `bundle audit` to check for known vulnerabilities
- Subscribe to security advisories for Ruby and gem dependencies

## Known Security Considerations

### File Parsing

PngConform uses BinData for binary parsing, which is a well-tested library. However:

- **Large files**: Set reasonable file size limits to prevent resource exhaustion
- **Malformed files**: The library handles malformed files gracefully, but very complex files may consume significant memory
- **Decompression bombs**: zlib decompression has limits, but extremely compressed files could still be problematic

### Regular Expression DoS (ReDoS)

All regular expressions in the codebase have been reviewed for potential ReDoS vulnerabilities. If you find any patterns that could cause exponential backtracking, please report them.

## Security Updates

Security updates will be released as soon as possible after a vulnerability is confirmed. Updates will be announced via:

- GitHub Security Advisories
- RubyGems security notifications
- CHANGELOG.md with security notes

## Acknowledgments

We appreciate the security research community's efforts to improve the security of PngConform. Security researchers who responsibly disclose vulnerabilities will be credited in:

- Security advisory
- CHANGELOG.md
- This document (if desired)

Thank you for helping keep PngConform and its users safe!