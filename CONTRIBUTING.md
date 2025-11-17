# Contributing to PngConform

Thank you for your interest in contributing to PngConform! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Code Style](#code-style)
- [Submitting Changes](#submitting-changes)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Set up your development environment
4. Create a topic branch for your changes
5. Make your changes
6. Test your changes
7. Submit a pull request

## Development Setup

### Prerequisites

- Ruby 3.0 or higher
- Bundler gem

### Setup Steps

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/png_conform.git
cd png_conform

# Install dependencies
bundle install

# Run tests to verify setup
bundle exec rake spec

# Run linter
bundle exec rubocop
```

## Making Changes

### Architecture Principles

PngConform follows strict architectural principles:

1. **Object-Oriented Design**: Use proper encapsulation, inheritance, and polymorphism
2. **MECE (Mutually Exclusive, Collectively Exhaustive)**: Each component should have exactly one responsibility
3. **Separation of Concerns**: Maintain clear boundaries between layers
4. **Model-Driven**: Prioritize model-to-model interaction over procedural code

### Directory Structure

```
lib/png_conform/
├── bindata/           # Binary parsing structures (BinData)
├── models/            # Domain models (Lutaml::Model)
├── validators/        # Validation logic
│   ├── critical/      # PNG critical chunks
│   ├── ancillary/     # PNG ancillary chunks
│   ├── apng/          # APNG chunks
│   ├── mng/           # MNG chunks
│   └── jng/           # JNG chunks
├── services/          # Orchestration and business logic
├── readers/           # File reading strategies
├── reporters/         # Output formatting
└── commands/          # CLI commands
```

### Adding a New Chunk Validator

1. Create the validator class in the appropriate directory:
   ```ruby
   # lib/png_conform/validators/ancillary/example_validator.rb
   module PngConform
     module Validators
       module Ancillary
         class ExampleValidator < BaseValidator
           def validate
             # Validation logic here
             check_length(expected_length)
             check_crc
             # Add errors/warnings/info as needed
           end
         end
       end
     end
   end
   ```

2. Register the validator in `lib/png_conform/validators/chunk_registry.rb`:
   ```ruby
   register("eXmP", Ancillary::ExampleValidator)
   ```

3. Add the require statement in `lib/png_conform.rb`:
   ```ruby
   require_relative "png_conform/validators/ancillary/example_validator"
   ```

4. Write comprehensive tests in `spec/png_conform/validators/ancillary/example_validator_spec.rb`

### Adding a New Validation Profile

1. Add profile definition in `lib/png_conform/services/profile_manager.rb`:
   ```ruby
   def example_profile
     Profile.new(
       name: "example",
       description: "Example profile for specific use case",
       required_chunks: %w[IHDR IDAT IEND],
       optional_chunks: %w[...],
       prohibited_chunks: %w[...]
     )
   end
   ```

2. Update documentation in `README.adoc`

3. Add tests for the new profile

## Testing

### Running Tests

```bash
# Run all tests
bundle exec rake spec

# Run specific test file
bundle exec rspec spec/path/to/spec_file.rb

# Run tests with coverage (if configured)
COVERAGE=true bundle exec rake spec
```

### Writing Tests

Follow these principles:

1. **One Test, One Behavior**: Each test should validate exactly one behavior
2. **Descriptive Names**: Use clear, descriptive test names
3. **Arrange-Act-Assert**: Structure tests with clear setup, execution, and assertion phases
4. **Use Doubles**: Prefer test doubles over real objects for isolation
5. **No Mocks for Models**: Don't mock domain model classes

Example test structure:

```ruby
RSpec.describe PngConform::Validators::Ancillary::ExampleValidator do
  describe "#validate" do
    let(:chunk) { create_chunk("eXmP", data) }
    let(:context) { PngConform::Validators::ValidationContext.new }
    subject(:validator) { described_class.new(chunk, context) }

    context "with valid data" do
      let(:data) { "\x00\x01\x02\x03" }

      it "does not add errors" do
        validator.validate
        expect(context.errors).to be_empty
      end
    end

    context "with invalid length" do
      let(:data) { "\x00\x01" }

      it "adds length error" do
        validator.validate
        expect(context.errors).to include(
          hash_including(message: /invalid length/)
        )
      end
    end
  end
end
```

### Test Coverage Requirements

- All new code must have corresponding tests
- Aim for 100% coverage of new functionality
- Tests must pass on all supported Ruby versions (3.0, 3.1, 3.2, 3.3)

## Code Style

### RuboCop

All code must pass RuboCop checks:

```bash
bundle exec rubocop

# Auto-fix issues where possible
bundle exec rubocop -A
```

### Ruby Style Guidelines

1. **Frozen String Literals**: Always use `# frozen_string_literal: true`
2. **Line Length**: Maximum 80 characters (exceptions allowed for readability)
3. **Method Length**: Keep methods focused and under 50 lines
4. **Class Length**: Keep classes under 700 lines (refactor if larger)
5. **No Hardcoding**: Use constants, configuration, or model properties

### Documentation

1. Use YARD-style comments for public APIs
2. Include examples in documentation
3. Update README.adoc for user-facing features
4. Update ARCHITECTURE.md for design changes

## Submitting Changes

### Pull Request Process

1. **Update Documentation**: Ensure README, CHANGELOG, and inline docs are updated
2. **Write Tests**: All new features must have comprehensive tests
3. **Run Quality Checks**:
   ```bash
   bundle exec rake spec    # All tests must pass
   bundle exec rubocop      # 0 offenses required
   ```

4. **Commit Messages**: Use semantic commit messages:
   ```
   feat(validators): add support for eXmP chunk
   fix(cli): correct argument parsing for --profile option
   docs(readme): update installation instructions
   test(validators): add tests for edge cases
   refactor(models): extract common validation logic
   chore(deps): update bindata to 2.5.1
   ```

5. **Create Pull Request**:
   - Provide clear description of changes
   - Reference any related issues
   - Include screenshots for UI changes
   - Ensure CI passes

### Pull Request Template

```markdown
## Description
Brief description of changes

## Motivation and Context
Why is this change required? What problem does it solve?

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update

## How Has This Been Tested?
Describe tests added or methodology used

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review of code completed
- [ ] Code comments added where needed
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests pass
- [ ] RuboCop passes with 0 offenses
- [ ] CHANGELOG.md updated
```

## Reporting Issues

### Bug Reports

When reporting bugs, please include:

1. **Ruby Version**: Output of `ruby -v`
2. **Gem Version**: Output of `png_conform version`
3. **Operating System**: OS and version
4. **Steps to Reproduce**: Minimal example to reproduce the issue
5. **Expected Behavior**: What you expected to happen
6. **Actual Behavior**: What actually happened
7. **Additional Context**: Any other relevant information

### Feature Requests

When requesting features, please include:

1. **Use Case**: Describe the problem this feature would solve
2. **Proposed Solution**: How you envision this feature working
3. **Alternatives**: Other approaches you've considered
4. **Additional Context**: Any other relevant information

## Development Resources

- [PNG Specification](https://www.w3.org/TR/PNG/)
- [MNG Specification](http://www.libpng.org/pub/mng/spec/)
- [APNG Specification](https://wiki.mozilla.org/APNG_Specification)
- [BinData Documentation](https://github.com/dmendel/bindata/wiki)
- [Lutaml Model Documentation](https://github.com/lutaml/lutaml-model)
- [Thor Documentation](http://whatisthor.com/)

## Questions?

If you have questions about contributing, please:

1. Check existing documentation (README, ARCHITECTURE)
2. Search existing issues and pull requests
3. Open a new issue with the "question" label

Thank you for contributing to PngConform!