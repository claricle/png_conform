# frozen_string_literal: true

require_relative "base_stage"

module PngConform
  module Pipelines
    module Stages
      # Signature validation stage
      #
      # Validates that the PNG file starts with the correct signature.
      #
      class SignatureValidationStage < BaseStage
        # Initialize signature validation stage
        #
        # @param reader [Object] File reader
        def initialize(reader)
          @reader = reader
        end

        # Execute signature validation
        #
        # @param result [PipelineResult] Current pipeline result
        # @return [PipelineResult] Updated pipeline result
        def execute(result)
          sig = @reader.signature
          expected = [137, 80, 78, 71, 13, 10, 26, 10].pack("C*")

          if sig != expected
            result.context.add_error(
              chunk_type: "SIGNATURE",
              message: "Invalid PNG signature",
              severity: :error,
            )
          end

          result
        end
      end
    end
  end
end
