# frozen_string_literal: true

require_relative "../container"
require_relative "validation_orchestrator"
require "etc"

module PngConform
  module Services
    # Parallel validator for processing multiple files simultaneously
    #
    # Uses multi-threading to validate multiple PNG files in parallel,
    # significantly reducing total validation time on multi-core systems.
    #
    # This service is MECE with ValidationOrchestrator - it handles
    # the coordination of multiple file validations, while
    # ValidationOrchestrator handles single file validation.
    #
    class ParallelValidator
      # Default number of threads based on CPU count
      DEFAULT_THREADS = [Etc.nprocessors, 4].max

      attr_reader :files, :options, :threads

      # Initialize parallel validator
      #
      # @param files [Array<String>] List of file paths to validate
      # @param options [Hash] CLI options for validation behavior
      def initialize(files, options = {})
        @files = files
        @options = options
        @threads = options.fetch(:threads, DEFAULT_THREADS)
      end

      # Validate all files in parallel
      #
      # Uses Ruby's Parallel gem to distribute work across threads.
      # Each file is validated independently using ValidationOrchestrator.
      #
      # @return [Array<FileAnalysis>] Array of validation results
      def validate_all
        require "parallel"

        Parallel.map(@files, in_threads: @threads) do |file_path|
          validate_single_file(file_path)
        end
      end

      # Validate all files with progress callback
      #
      # @param progress_callback [Proc] Callback for progress updates
      # @return [Array<FileAnalysis>] Array of validation results
      def validate_all_with_progress(progress_callback = nil)
        require "parallel"

        completed = 0
        total = @files.size

        Parallel.map(@files, in_threads: @threads) do |file_path|
          result = validate_single_file(file_path)

          # Report progress if callback provided
          if progress_callback
            completed += 1
            progress_callback.call(completed, total, file_path)
          end

          result
        end
      end

      private

      # Validate a single file
      #
      # Uses StreamingReader and ValidationOrchestrator for validation.
      # Returns error hash if validation fails.
      #
      # @param file_path [String] Path to PNG file
      # @return [FileAnalysis, Hash] Validation result or error hash
      def validate_single_file(file_path)
        # Check file existence first (avoid thread overhead for missing files)
        unless File.exist?(file_path)
          return {
            error: "File not found: #{file_path}",
            file: file_path,
            valid: false,
          }
        end

        unless File.file?(file_path)
          return {
            error: "Not a file: #{file_path}",
            file: file_path,
            valid: false,
          }
        end

        # Use container to create reader and orchestrator
        Container.open_reader(:streaming, file_path) do |reader|
          orchestrator = Container.validation_orchestrator(
            reader,
            file_path,
            @options.merge(filepath: file_path),
          )
          orchestrator.validate
        end
      rescue StandardError => e
        # Return error hash instead of raising (keeps parallel processing going)
        {
          error: e.message,
          file: file_path,
          valid: false,
          backtrace: @options[:verbose] ? e.backtrace.first(10) : nil,
        }
      end
    end
  end
end
