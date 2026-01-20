# frozen_string_literal: true

module PngConform
  module Pipelines
    # Result object for pipeline stages
    #
    # Carries state through the validation pipeline.
    #
    class PipelineResult
      attr_accessor :ready_for_analysis
      attr_reader :context, :chunks

      # Initialize pipeline result
      #
      # @param context [ValidationContext] Validation context
      # @param chunks [Array] Array of chunks
      def initialize(context:, chunks: [])
        @context = context
        @chunks = chunks
        @ready_for_analysis = false
      end

      # Check if validation has errors
      #
      # @return [Boolean] true if there are errors
      def has_errors?
        @context.has_errors?
      end

      # Check if validation should terminate early
      #
      # @param fail_fast [Boolean] Whether fail_fast is enabled
      # @return [Boolean] true if should terminate
      def should_terminate?(fail_fast: false)
        fail_fast && has_errors?
      end
    end
  end
end
