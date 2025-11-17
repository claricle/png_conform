# frozen_string_literal: true

require_relative "../services/validation_service"
require_relative "../services/profile_manager"
require_relative "../reporters/reporter_factory"
require_relative "../readers/streaming_reader"

module PngConform
  module Commands
    # Command to validate PNG files and report results.
    #
    # Coordinates between readers, validators, and reporters to analyze
    # PNG files according to specified options and profiles.
    class CheckCommand
      attr_reader :files, :options

      # @param files [Array<String>] List of file paths to validate
      # @param options [Hash] Command-line options
      def initialize(files, options = {})
        @files = files
        @options = options
        @errors_found = false
      end

      # Execute the validation command.
      #
      # @return [Integer] Exit code (0 for success, 1 for errors)
      def run
        validate_inputs
        validate_files
        exit_code
      end

      private

      # Validate command inputs and options.
      def validate_inputs
        if files.empty?
          puts "Error: No files specified"
          puts "Usage: png_conform check [OPTIONS] FILES"
          exit(1)
        end

        # Check if profile exists (if specified)
        if options[:profile] && !Services::ProfileManager.profile_exists?(options[:profile])
          puts "Error: Unknown profile '#{options[:profile]}'"
          puts "Available profiles: #{Services::ProfileManager.available_profiles.join(', ')}"
          exit(1)
        end

        # Check for conflicting options
        if options[:quiet] && options[:verbose]
          puts "Warning: --quiet and --verbose are mutually exclusive, using --quiet"
          options[:verbose] = false
        end

        return unless options[:quiet] && options[:very_verbose]

        puts "Warning: --quiet and --very-verbose are mutually exclusive, using --quiet"
        options[:very_verbose] = false
      end

      # Validate all specified files.
      def validate_files
        reporter = create_reporter

        files.each do |file_path|
          validate_single_file(file_path, reporter)
        end
      end

      # Validate a single PNG file.
      #
      # @param file_path [String] Path to the PNG file
      # @param reporter [Reporters::BaseReporter] Reporter for output
      def validate_single_file(file_path, reporter)
        unless File.exist?(file_path)
          puts "Error: File not found: #{file_path}"
          @errors_found = true
          return
        end

        unless File.file?(file_path)
          puts "Error: Not a file: #{file_path}"
          @errors_found = true
          return
        end

        # Read and validate the file using streaming reader
        Readers::StreamingReader.open(file_path) do |reader|
          # Perform validation
          validator = Services::ValidationService.new(reader, file_path)
          file_analysis = validator.validate

          # Track if any errors were found
          @errors_found = true unless file_analysis.valid?

          # Use reporter to output result
          reporter.report(file_analysis)

          # For text output (default), show additional analysis unless quiet
          if (options[:format].nil? || options[:format] == "text") && !options[:quiet]
            show_resolution_analysis(file_analysis)
            show_optimization_suggestions(file_analysis)
          end

          # Explicit flags always show
          show_metrics(file_analysis) if options[:metrics]
          show_mobile_readiness(file_analysis) if options[:mobile_ready]
        end
      rescue StandardError => e
        puts "Error processing #{file_path}: #{e.message}"
        puts e.backtrace.join("\n") if options[:verbose]
        @errors_found = true
      end

      # Create the appropriate reporter based on options.
      #
      # @return [Reporters::BaseReporter] Reporter instance
      def create_reporter
        Reporters::ReporterFactory.create(
          format: options[:format] || "text",
          verbose: options[:verbose] || options[:very_verbose],
          quiet: options[:quiet],
          colorize: !options[:no_color],
          show_palette: options[:palette],
          show_text: options[:text],
          seven_bit: options[:seven_bit],
        )
      end

      # Show optimization suggestions for the file
      def show_optimization_suggestions(file_analysis)
        analysis = file_analysis.optimization_analysis
        return unless analysis && analysis[:suggestions]
        return if analysis[:suggestions].empty?

        puts "\n#{colorize('OPTIMIZATION SUGGESTIONS:', :bold)}"
        analysis[:suggestions].each_with_index do |suggestion, index|
          priority_color = priority_color(suggestion[:priority])
          priority_label = suggestion[:priority].to_s.upcase

          puts "  #{index + 1}. [#{colorize(priority_label,
                                            priority_color)}] #{suggestion[:description]}"
          if suggestion[:savings_bytes]&.positive?
            puts "     Savings: #{format_bytes(suggestion[:savings_bytes])}"
          end
        end

        total_savings = analysis[:potential_savings_bytes]
        if total_savings.positive?
          puts "\n  #{colorize('Total Potential Savings:', :bold)} " \
               "#{format_bytes(total_savings)} (#{analysis[:potential_savings_percent]}%)"
        end
      end

      # Show comprehensive metrics
      def show_metrics(file_analysis)
        metrics = file_analysis.metrics
        return unless metrics

        case options[:format]
        when "json"
          require "json"
          puts JSON.pretty_generate(metrics)
        when "yaml"
          require "yaml"
          puts metrics.to_yaml
        else
          # Text format with colored output
          puts "\n#{colorize('METRICS:', :bold)}"
          puts "  File: #{metrics[:file][:filename]} (#{metrics[:file][:size_kb]} KB)"
          puts "  Image: #{metrics[:image][:dimensions]}, #{metrics[:image][:color_type_name]}, " \
               "#{metrics[:image][:bit_depth]}-bit"
          puts "  Chunks: #{metrics[:chunks][:total_count]} (#{metrics[:chunks][:types].join(', ')})"
          puts "  Validation: #{metrics[:validation][:error_count]} errors, " \
               "#{metrics[:validation][:warning_count]} warnings"
        end
      end

      # Show resolution and Retina analysis
      def show_resolution_analysis(file_analysis)
        analysis = file_analysis.resolution_analysis
        return unless analysis

        puts "\n#{colorize('RESOLUTION ANALYSIS:', :bold)}"

        # Basic info
        res = analysis[:resolution]
        puts "  Dimensions: #{res[:dimensions]} (#{res[:megapixels]} megapixels)"
        puts "  DPI: #{res[:dpi] || 'Not specified'}"

        # Retina analysis
        puts "\n  #{colorize('Retina Analysis:', :bold)}"
        retina = analysis[:retina]
        puts "    @1x: #{retina[:at_1x][:dimensions_pt]} (#{retina[:at_1x][:suitable_for].first})"
        puts "    @2x: #{retina[:at_2x][:dimensions_pt]} (#{retina[:at_2x][:suitable_for].first})"
        puts "    @3x: #{retina[:at_3x][:dimensions_pt]} (#{retina[:at_3x][:suitable_for].first})"
        puts "    Recommended: #{retina[:recommended_density]}"

        # iOS suggestions
        ios = retina[:ios_asset_catalog]
        if ios && !ios.empty?
          puts "    iOS: #{ios.join(', ')}"
        end

        # Android
        puts "    Android: #{retina[:android_density]}"

        # Print analysis if DPI available
        if analysis[:print][:capable]
          print_info = analysis[:print]
          puts "\n  #{colorize('Print Analysis:', :bold)}"
          puts "    Quality: #{print_info[:quality]} (#{print_info[:dpi]} DPI)"
          phys = print_info[:physical_size]
          puts "    Physical Size: #{phys[:width_inches]}\" x #{phys[:height_inches]}\" " \
               "(#{phys[:width_cm]} x #{phys[:height_cm]} cm)"
        end

        # Recommendations
        recommendations = analysis[:recommendations]
        if recommendations && !recommendations.empty?
          puts "\n  #{colorize('Recommendations:', :bold)}"
          recommendations.each do |rec|
            priority_color = priority_color(rec[:priority])
            puts "    [#{colorize(rec[:priority].to_s.upcase,
                                  priority_color)}] #{rec[:message]}"
          end
        end
      end

      # Show mobile and Retina readiness
      def show_mobile_readiness(file_analysis)
        analysis = file_analysis.resolution_analysis
        return unless analysis

        puts "\n#{colorize('MOBILE & RETINA READINESS:', :bold)}"

        retina = analysis[:retina]
        web = analysis[:web]

        # Overall readiness
        is_ready = retina[:is_retina_ready] && web[:mobile_friendly]
        status = if is_ready
                   colorize("✓ READY",
                            :green)
                 else
                   colorize("✗ NOT READY", :red)
                 end
        puts "  Status: #{status}"

        # Specific checks
        puts "\n  Checks:"
        puts "    Retina Ready: #{format_check(retina[:is_retina_ready])}"
        puts "    Mobile Friendly: #{format_check(web[:mobile_friendly])}"
        puts "    Web Suitable: #{format_check(web[:suitable_for_web])}"

        # Retina densities
        puts "\n  Retina Densities:"
        puts "    @1x: #{retina[:at_1x][:dimensions_pt]}"
        puts "    @2x: #{retina[:at_2x][:dimensions_pt]}"
        puts "    @3x: #{retina[:at_3x][:dimensions_pt]}"
        puts "    Recommended: #{retina[:recommended_density]}"

        # Screen coverage
        puts "\n  Screen Coverage:"
        web[:typical_screen_size].each do |screen, coverage|
          puts "    #{screen}: #{coverage}"
        end

        # Load time
        puts "\n  Load Time: #{web[:load_time_estimate]}"
      end

      # Helper methods for formatting

      def format_check(passed)
        passed ? colorize("✓", :green) : colorize("✗", :red)
      end

      def format_bytes(bytes)
        if bytes < 1024
          "#{bytes} bytes"
        elsif bytes < 1024 * 1024
          "#{(bytes / 1024.0).round(2)} KB"
        else
          "#{(bytes / 1024.0 / 1024.0).round(2)} MB"
        end
      end

      def priority_color(priority)
        case priority
        when :high then :red
        when :medium then :yellow
        when :low then :blue
        else :default
        end
      end

      def colorize(text, color)
        return text if options[:no_color]

        codes = {
          red: "\e[31m",
          green: "\e[32m",
          yellow: "\e[33m",
          blue: "\e[34m",
          bold: "\e[1m",
          reset: "\e[0m",
        }

        "#{codes[color]}#{text}#{codes[:reset]}"
      end

      # Determine the exit code based on whether errors were found.
      #
      # @return [Integer] Exit code (0 for success, 1 for errors)
      def exit_code
        @errors_found ? 1 : 0
      end
    end
  end
end
