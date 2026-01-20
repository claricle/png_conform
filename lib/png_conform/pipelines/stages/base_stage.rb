# frozen_string_literal: true

module PngConform
  module Pipelines
    module Stages
      # Base class for validation pipeline stages
      #
      # All pipeline stages inherit from this class and implement
      # the execute method. This provides a consistent interface
      # for pipeline execution.
      #
      class BaseStage
        # Execute the stage
        #
        # @param result [PipelineResult] Current pipeline result
        # @return [PipelineResult] Updated pipeline result
        def execute(result)
          raise NotImplementedError, "Subclasses must implement #execute"
        end
      end
    end
  end
end
