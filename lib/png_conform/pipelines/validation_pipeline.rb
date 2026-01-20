# frozen_string_literal: true

require_relative "pipeline_result"
require_relative "stages/base_stage"
require_relative "stages/signature_validation_stage"
require_relative "stages/chunk_validation_stage"
require_relative "stages/sequence_validation_stage"
require_relative "stages/analysis_stage"
require_relative "../services/result_builder"
require_relative "../services/analysis_manager"

module PngConform
  module Pipelines
    # Validation pipeline for PNG files
    #
    # Executes validation in a series of stages:
    # 1. Signature validation
    # 2. Chunk validation
    # 3. Sequence validation
    # 4. Analysis preparation
    #
    class ValidationPipeline
      # Initialize validation pipeline
      #
      # @param reader [Object] File reader
      # @param options [Hash] Validation options
      def initialize(reader, options = {})
        @reader = reader
        @options = options
        @context = Validators::ValidationContext.new
        @chunks = []
        build_stages
      end

      # Execute the validation pipeline
      #
      # Runs all stages in order. Stops early if fail_fast is enabled
      # and critical errors are encountered.
      #
      # @return [FileAnalysis] Complete file analysis
      def execute
        result = PipelineResult.new(context: @context, chunks: @chunks)

        @stages.each do |stage|
          result = stage.execute(result)

          # Early termination for critical errors
          break if result.should_terminate?(fail_fast: @options[:fail_fast])
        end

        build_file_analysis(result)
      end

      private

      # Build the pipeline stages
      #
      # @return [void]
      def build_stages
        @stages = [
          Stages::SignatureValidationStage.new(@reader),
          Stages::ChunkValidationStage.new(@reader, @context, @options),
          Stages::SequenceValidationStage.new(@context),
          Stages::AnalysisStage.new(@context, @options),
        ]
      end

      # Build complete FileAnalysis from pipeline result
      #
      # @param result [PipelineResult] Pipeline result
      # @return [FileAnalysis] Complete file analysis
      def build_file_analysis(_result)
        result_builder = Services::ResultBuilder.new(
          @reader,
          @options[:filepath],
          @context,
          @chunks,
          @options,
        )
        file_analysis = result_builder.build

        # Run analyzers through AnalysisManager
        analysis_manager = Services::AnalysisManager.new(@options)
        analysis_manager.enrich(file_analysis)

        file_analysis
      end
    end
  end
end
