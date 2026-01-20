# frozen_string_literal: true

require_relative "chunk_processor"
require_relative "result_builder"
require_relative "analysis_manager"

module PngConform
  module Services
    # Main validation orchestration service
    #
    # This service coordinates the validation of PNG files by:
    # 1. Validating the PNG signature
    # 2. Processing chunks through ChunkProcessor
    # 3. Validating chunk sequence requirements
    # 4. Building the complete FileAnalysis result
    #
    # The orchestrator follows a pipeline architecture:
    # File → Signature → Chunks → Sequence → Analysis → Result
    #
    class ValidationOrchestrator
      attr_reader :reader, :filepath, :options, :context, :chunks

      # Convenience method to validate a file by path
      #
      # @param filepath [String] Path to PNG file
      # @param options [Hash] Optional CLI options
      # @return [FileAnalysis] Complete file analysis
      def self.validate_file(filepath, options = {})
        require_relative "../readers/full_load_reader"
        reader = Readers::FullLoadReader.new(filepath)
        new(reader, filepath, options).validate
      end

      # Initialize validation orchestrator
      #
      # @param reader [Object] File reader (StreamingReader or FullLoadReader)
      # @param filepath [String, nil] Optional file path (for reporting)
      # @param options [Hash] CLI options for controlling behavior
      def initialize(reader, filepath = nil, options = {})
        @reader = reader
        @filepath = filepath
        @options = options
        @context = Validators::ValidationContext.new
        @chunks = []
      end

      # Validate the PNG file
      #
      # This is the main entry point for validation. It orchestrates
      # all validation stages in the correct order.
      #
      # @return [FileAnalysis] Complete file analysis with all data
      def validate
        validate_signature
        process_chunks
        validate_sequence
        build_result
      end

      # Get all errors from the validation context
      #
      # @return [Array<Hash>] Array of error hashes
      def errors
        @context.all_errors
      end

      # Get all warnings from the validation context
      #
      # @return [Array<Hash>] Array of warning hashes
      def warnings
        @context.all_warnings
      end

      # Get all info messages from the validation context
      #
      # @return [Array<Hash>] Array of info hashes
      def info_messages
        @context.all_info
      end

      private

      # Validate PNG signature
      #
      # Checks that the file starts with the PNG signature:
      # 137 80 78 71 13 10 26 10
      #
      # @return [void]
      def validate_signature
        sig = reader.signature
        expected = [137, 80, 78, 71, 13, 10, 26, 10].pack("C*")

        return if sig == expected

        @context.add_error(
          chunk_type: "SIGNATURE",
          message: "Invalid PNG signature",
          severity: :error,
        )
      end

      # Process all chunks using ChunkProcessor
      #
      # Delegates chunk validation to the ChunkProcessor which handles:
      # - Iterating through chunks
      # - Creating validators via ChunkRegistry
      # - Collecting validation results
      #
      # @return [void]
      def process_chunks
        processor = ChunkProcessor.new(@reader, @context, @options)
        processor.process do |chunk|
          @chunks << chunk
        end
      end

      # Validate chunk sequence requirements
      #
      # Checks high-level sequencing rules:
      # - IHDR must be first chunk
      # - IEND must be last chunk
      # - At least one IDAT chunk required
      #
      # @return [void]
      def validate_sequence
        validate_ihdr_first
        validate_iend_last
        validate_idat_present
      end

      # Check that IHDR is the first chunk
      #
      # @return [void]
      def validate_ihdr_first
        return if @context.seen?("IHDR")

        @context.add_error(
          chunk_type: "IHDR",
          message: "Missing IHDR chunk (must be first)",
          severity: :error,
        )
      end

      # Check that IEND is the last chunk
      #
      # @return [void]
      def validate_iend_last
        return if @context.seen?("IEND")

        @context.add_error(
          chunk_type: "IEND",
          message: "Missing IEND chunk (must be last)",
          severity: :error,
        )
      end

      # Check that at least one IDAT chunk exists
      #
      # @return [void]
      def validate_idat_present
        return if @context.seen?("IDAT")

        @context.add_error(
          chunk_type: "IDAT",
          message: "Missing IDAT chunk (at least one required)",
          severity: :error,
        )
      end

      # Build complete FileAnalysis with validation results and analyzer data
      #
      # Coordinates ResultBuilder and AnalysisManager to produce the final result
      #
      # @return [FileAnalysis] Complete analysis model
      def build_result
        result_builder = ResultBuilder.new(@reader, @filepath, @context,
                                           @chunks, @options)
        file_analysis = result_builder.build

        # Run analyzers through AnalysisManager
        analysis_manager = AnalysisManager.new(@options)
        analysis_manager.enrich(file_analysis)

        file_analysis
      end
    end
  end
end
