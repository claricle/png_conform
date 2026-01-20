# frozen_string_literal: true

require_relative "base_stage"

module PngConform
  module Pipelines
    module Stages
      # Chunk sequence validation stage
      #
      # Validates high-level chunk sequence requirements:
      # - IHDR must be first chunk
      # - IEND must be last chunk
      # - At least one IDAT chunk required
      #
      class SequenceValidationStage < BaseStage
        # Initialize sequence validation stage
        #
        # @param context [ValidationContext] Validation context
        def initialize(context)
          @context = context
        end

        # Execute sequence validation
        #
        # @param result [PipelineResult] Current pipeline result
        # @return [PipelineResult] Updated pipeline result
        def execute(result)
          validate_ihdr_first
          validate_iend_last
          validate_idat_present
          result
        end

        private

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
      end
    end
  end
end
