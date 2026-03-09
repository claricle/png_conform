# frozen_string_literal: true

require "thor"
require_relative "commands/check_command"
require_relative "commands/list_command"

module PngConform
  # Main CLI application class using Thor framework.
  #
  # Provides the command-line interface for PNG validation and analysis.
  # Delegates to command classes for implementation.
  class Cli < Thor
    class_option :verbose,
                 type: :boolean,
                 default: false,
                 desc: "Enable verbose output"

    desc "check FILES", "Validate PNG files"
    long_desc <<~DESC
            Validate one or more PNG files and report any errors or warnings.

            Options:
              -f, --format FORMAT     Output format: text, yaml, json (default: text)
              -v, --verbose           Print detailed chunk information
              -vv, --very-verbose     Print very detailed information including \
      line filters
              -q, --quiet             Only output errors (suppress success messages)
              --no-color              Disable colored output (colors enabled by default)
              -p, --palette           Print palette and histogram chunks
              -t, --text              Print text chunk contents
              -7, --seven-bit         Escape characters >= 128 for 7-bit terminals
              --profile PROFILE       Validate against a specific profile \
      (minimal, web, print, archive, strict, default)
              --strict                Enable strict validation mode
              --optimize              Show optimization suggestions
              --metrics               Show detailed metrics (JSON/YAML)
              --resolution            Show resolution and Retina analysis
              --mobile-ready          Check mobile and Retina readiness
              --batch                 Enable batch chunk validation (default: enabled)
              --no-batch              Disable batch chunk validation
              --parallel, -j         Enable parallel processing for multiple files
              --jobs, -j NUM         Number of parallel threads (default: CPU count)

            Examples:
              png_conform check image.png
              png_conform check -v image.png
              png_conform check --optimize image.png
              png_conform check --resolution icon@2x.png
              png_conform check --metrics --format json image.png
              png_conform check --mobile-ready app-icon.png
              png_conform check --profile web *.png
    DESC
    option :format, aliases: :f, type: :string, default: "text",
                    desc: "Output format (text, yaml, json)"
    option :very_verbose, aliases: :vv, type: :boolean, default: false,
                          desc: "Print very detailed information"
    option :quiet, aliases: :q, type: :boolean, default: false,
                   desc: "Only output errors"
    option :no_color, type: :boolean, default: false,
                      desc: "Disable colored output"
    option :palette, aliases: :p, type: :boolean, default: false,
                     desc: "Print palette and histogram chunks"
    option :text, aliases: :t, type: :boolean, default: false,
                  desc: "Print text chunk contents"
    option :seven_bit, aliases: :"7", type: :boolean, default: false,
                       desc: "Escape chars >= 128"
    option :profile, type: :string, default: nil,
                     desc: "Validation profile"
    option :strict, type: :boolean, default: false,
                    desc: "Strict validation mode"
    option :optimize, type: :boolean, default: false,
                      desc: "Show file size optimization suggestions"
    option :metrics, type: :boolean, default: false,
                     desc: "Show comprehensive metrics"
    option :resolution, type: :boolean, default: false,
                        desc: "Show resolution and Retina/DPI analysis"
    option :mobile_ready, type: :boolean, default: false,
                          desc: "Check mobile and Retina readiness"
    option :batch, type: :boolean, default: true,
                   desc: "Enable batch chunk validation (faster for files with many chunks)"
    option :no_batch, type: :boolean, default: false,
                      desc: "Disable batch chunk validation"
    option :parallel, type: :boolean, default: false, aliases: "-j",
                      desc: "Enable parallel processing for multiple files"
    option :jobs, type: :numeric, default: nil, aliases: "-j",
                  desc: "Number of parallel threads (default: CPU count)"
    def check(*files)
      Commands::CheckCommand.new(files, options).run
    end

    desc "list", "List available validation profiles"
    long_desc <<~DESC
      Display all available validation profiles and their requirements.

      Profiles define different validation rules for different use cases:
        - minimal: Basic PNG structure validation
        - web: Browser-optimized validation
        - print: Print-ready validation with physical dimensions
        - archive: Long-term preservation with full metadata
        - strict: Strictest possible validation
        - default: Balanced validation for general use

      Examples:
        png_conform list
    DESC
    def list
      Commands::ListCommand.new(options).run
    end

    desc "version", "Display version information"
    def version
      puts "png_conform version #{PngConform::VERSION}"
      puts "Ruby version #{RUBY_VERSION}"
    end

    # Override default error handling to provide helpful messages
    def self.exit_on_failure?
      true
    end
  end
end
