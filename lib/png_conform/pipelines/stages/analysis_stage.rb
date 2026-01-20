# frozen_string_literal: true

require_relative "base_stage"

module PngConform
  module Pipelines
    module Stages
      # Analysis enrichment stage
      #
      # Runs conditional analyzers based on options.
      #
      class AnalysisStage < BaseStage
        # Initialize analysis stage
        #
        # @param context [ValidationContext] Validation context
        # @param options [Hash] Validation options
        def initialize(context, options)
          @context = context
          @options = options
        end

        # Execute analysis enrichment
        #
        # @param result [PipelineResult] Current pipeline result
        # @return [PipelineResult] Updated pipeline result
        def execute(result)
          # Analysis is performed later during FileAnalysis building
          # This stage just marks the pipeline as ready for analysis
          result.ready_for_analysis = true
          result
        end
      end
    end
  end
end
