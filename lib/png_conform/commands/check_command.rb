# frozen_string_literal: true

require_relative "../container"
require_relative "../utils/colorizer"
require_relative "../services/profile_manager"
require_relative "../reporters/reporter_factory"

module PngConform
  module Commands
    # Command to validate PNG files and report results.
    #
    # Coordinates between readers, validators, and reporters to analyze
    # PNG files according to specified options and profiles.
    #
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
          raise PngConform::NoFilesSpecifiedError.new
        end

        # Check if profile exists (if specified)
        if options[:profile] && !Services::ProfileManager.profile_exists?(options[:profile])
          puts "Error: Unknown profile '#{options[:profile]}'"
          puts "Available profiles: #{Services::ProfileManager.available_profiles.join(', ')}"
          raise PngConform::UnknownProfileError.new(options[:profile],
                                                    Services::ProfileManager.available_profiles)
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
      #
      # Uses parallel validation if --parallel flag is set with multiple files.
      # Otherwise processes files sequentially.
      def validate_files
        reporter = create_reporter

        # Use parallel validation if enabled and multiple files
        if files.length > 1 && @options[:parallel]
          validate_files_parallel(reporter)
        else
          validate_files_sequential(reporter)
        end
      end

      # Validate files sequentially (original behavior)
      #
      # @param reporter [Reporters::BaseReporter] Reporter for output
      def validate_files_sequential(reporter)
        files.each do |file_path|
          validate_single_file(file_path, reporter)
        end
      end

      # Validate files in parallel for better performance
      #
      # @param reporter [Reporters::BaseReporter] Reporter for output
      def validate_files_parallel(reporter)
        require_relative "../services/parallel_validator"

        parallel_validator = Services::ParallelValidator.new(files, @options)
        results = parallel_validator.validate_all

        # Process results and report
        results.each do |result|
          if result.key?(:error)
            handle_validation_error(result)
            next
          end

          @errors_found = true unless result.valid?
          reporter.report(result)

          # Show additional analysis for text format
          show_additional_analysis(result) if should_show_analysis?
        end
      rescue Interrupt
        # Handle Ctrl+C gracefully
        puts "\nValidation interrupted by user."
        raise
      rescue StandardError => e
        puts "Error during parallel validation: #{e.message}"
        puts e.backtrace.join("\n") if @options[:verbose]
        @errors_found = true
      end

      # Handle validation error from parallel processing
      #
      # @param error_result [Hash] Error result from parallel validation
      def handle_validation_error(error_result)
        puts "Error: #{error_result[:error]}"
        @errors_found = true

        if error_result[:backtrace] && @options[:verbose]
          puts "Backtrace:"
          error_result[:backtrace].each { |line| puts "  #{line}" }
        end
      end

      # Check if additional analysis should be shown
      #
      # @return [Boolean] True if analysis should be shown
      def should_show_analysis?
        return false if @options[:quiet]
        return true if @options[:metrics] || @options[:mobile_ready] || @options[:resolution] || @options[:optimize]

        # Text format shows analysis by default (unless quiet)
        @options[:format].nil? || @options[:format] == "text"
      end

      # Show additional analysis (resolution, optimization, metrics)
      #
      # @param file_analysis [FileAnalysis] File analysis results
      def show_additional_analysis(file_analysis)
        show_resolution_analysis(file_analysis) if @options[:resolution] || @options[:mobile_ready]
        show_optimization_suggestions(file_analysis) if @options[:optimize]
        show_metrics(file_analysis) if @options[:metrics]
        show_mobile_readiness(file_analysis) if @options[:mobile_ready]

        # Default: show resolution and optimization for text format (unless quiet)
        if (@options[:format].nil? || @options[:format] == "text") &&
            !@options[:quiet] &&
            !@options[:resolution] &&
            !@options[:mobile_ready] &&
            !@options[:optimize]
          show_resolution_analysis(file_analysis)
          show_optimization_suggestions(file_analysis)
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

        # Use container to create reader and orchestrator
        Container.open_reader(:streaming, file_path) do |reader|
          options_with_path = @options.merge(filepath: file_path)
          orchestrator = Container.validation_orchestrator(reader, file_path,
                                                           options_with_path)
          file_analysis = orchestrator.validate

          # Track if any errors were found
          @errors_found = true unless file_analysis.valid?

          # Use reporter to output result
          reporter.report(file_analysis)

          # Show additional analysis
          show_additional_analysis(file_analysis) if should_show_analysis?
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
        Container.reporter(
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

        puts "\n#{Utils::Colorizer.bold('OPTIMIZATION SUGGESTIONS:')}"
        analysis[:suggestions].each_with_index do |suggestion, index|
          puts "  #{index + 1}. #{Utils::Colorizer.priority(suggestion[:description],
                                                            suggestion[:priority])}"
          if suggestion[:savings_bytes]&.positive?
            puts "     Savings: #{format_bytes(suggestion[:savings_bytes])}"
          end
        end

        total_savings = analysis[:potential_savings_bytes]
        if total_savings.positive?
          puts "\n  #{Utils::Colorizer.bold('Total Potential Savings:')} " \
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
          puts "\n#{Utils::Colorizer.bold('METRICS:')}"
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

        puts "\n#{Utils::Colorizer.bold('RESOLUTION ANALYSIS:')}"

        # Basic info
        res = analysis[:resolution]
        puts "  Dimensions: #{res[:dimensions]} (#{res[:megapixels]} megapixels)"
        puts "  DPI: #{res[:dpi] || 'Not specified'}"

        # Retina analysis
        puts "\n  #{Utils::Colorizer.bold('Retina Analysis:')}"
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
          puts "\n  #{Utils::Colorizer.bold('Print Analysis:')}"
          puts "    Quality: #{print_info[:quality]} (#{print_info[:dpi]} DPI)"
          phys = print_info[:physical_size]
          puts "    Physical Size: #{phys[:width_inches]}\" x #{phys[:height_inches]}\" " \
               "(#{phys[:width_cm]} x #{phys[:height_cm]} cm)"
        end

        # Recommendations
        recommendations = analysis[:recommendations]
        if recommendations && !recommendations.empty?
          puts "\n  #{Utils::Colorizer.bold('Recommendations:')}"
          recommendations.each do |rec|
            puts "    #{Utils::Colorizer.priority(rec[:message],
                                                  rec[:priority])}"
          end
        end
      end

      # Show mobile and Retina readiness
      def show_mobile_readiness(file_analysis)
        analysis = file_analysis.resolution_analysis
        return unless analysis

        puts "\n#{Utils::Colorizer.bold('MOBILE & RETINA READINESS:')}"

        retina = analysis[:retina]
        web = analysis[:web]

        # Overall readiness
        is_ready = retina[:is_retina_ready] && web[:mobile_friendly]
        status = if is_ready
                   Utils::Colorizer.success("✓ READY")
                 else
                   Utils::Colorizer.error("✗ NOT READY")
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
        passed ? Utils::Colorizer.success("✓") : Utils::Colorizer.error("✗")
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

      # Determine the exit code based on whether errors were found.
      #
      # @return [Integer] Exit code (0 for success, 1 for errors)
      def exit_code
        @errors_found ? 1 : 0
      end
    end
  end
end
