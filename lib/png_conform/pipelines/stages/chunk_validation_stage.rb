# frozen_string_literal: true

require_relative "base_stage"
require_relative "../../services/chunk_processor"
require_relative "../../models/pipeline_result"

module PngConform
  module Pipelines
    module Stages
      # Chunk validation stage
      #
      # Processes all chunks through validation using ChunkProcessor.
      # Caches CRC calculations during initial read to avoid recomputation.
      #
      class ChunkValidationStage < BaseStage
        # Initialize chunk validation stage
        #
        # @param reader [Object] File reader
        # @param context [ValidationContext] Validation context
        # @param options [Hash] Validation options
        def initialize(reader, context, options = {})
          @reader = reader
          @context = context
          @options = options
          @crc_cache = {} # Cache for CRC calculations
        end

        # Execute chunk validation
        #
        # @param result [PipelineResult] Current pipeline result
        # @return [PipelineResult] Updated pipeline result
        def execute(result)
          processor = Services::ChunkProcessor.new(@reader, @context, @options)
          processor.process do |chunk|
            # Cache CRC during initial read to avoid recalculation
            cache_crc(chunk)
            result.chunks << chunk
          end

          result
        end

        private

        # Cache CRC calculation for a chunk
        #
        # Performance optimization: calculates CRC once during initial read
        # and stores it for later use in result building.
        #
        # @param chunk [Object] Chunk to cache CRC for
        # @return [void]
        def cache_crc(chunk)
          return unless chunk.respond_to?(:chunk_type) && chunk.respond_to?(:data)

          key = "#{chunk.chunk_type}_#{chunk.data.hash}"
          @crc_cache[key] ||= calculate_crc(chunk)

          # Store cached CRC on chunk for later access
          chunk.instance_variable_set(:@cached_crc, @crc_cache[key])
        end

        # Calculate CRC32 for a chunk
        #
        # @param chunk [Object] BinData chunk
        # @return [Integer] CRC32 value
        def calculate_crc(chunk)
          require "zlib"
          # CRC is calculated over chunk type + chunk data
          Zlib.crc32(chunk.chunk_type.to_s + chunk.data.to_s)
        end
      end
    end
  end
end
