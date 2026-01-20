# frozen_string_literal: true

require_relative "../validators/chunk_registry"
require_relative "validator_pool"

module PngConform
  module Services
    # Processes chunks through validation pipeline
    #
    # The ChunkProcessor handles:
    # - Iterating through chunks from the reader
    # - Creating validators via ChunkRegistry
    # - Collecting validation results
    # - Handling unknown chunk types
    #
    # This class extracts chunk processing logic from ValidationService
    # following Single Responsibility Principle.
    #
    class ChunkProcessor
      # Initialize chunk processor
      #
      # @param reader [Object] File reader (StreamingReader or FullLoadReader)
      # @param context [ValidationContext] Validation context for state
      # @param options [Hash] CLI options for controlling behavior
      def initialize(reader, context, options = {})
        @reader = reader
        @context = context
        @options = options
        @validator_pool = ValidatorPool.new(options.slice(:max_per_type))
      end

      # Process all chunks from the reader
      #
      # Uses batch validation by default for performance (groups chunks by type).
      # Falls back to individual processing if batch_disabled option is set.
      # Supports early termination if fail_fast option is enabled.
      #
      # @yield [chunk] Optional block to receive chunks as they're processed
      # @return [void]
      def process(&block)
        # Use batch validation by default (faster for files with many chunks)
        if @options[:batch_enabled] == false
          process_individual(&block)
        else
          process_batch_inline(&block)
        end
      end

      private

      # Process chunks in batch inline (collecting from reader)
      #
      # Performance optimization: groups chunks by type and validates
      # in batches to reduce validator instantiation overhead.
      #
      # @return [void]
      def process_batch_inline
        # Collect all chunks first
        chunk_groups = Hash.new { |h, k| h[k] = [] }

        @reader.each_chunk do |chunk|
          chunk_groups[chunk.chunk_type.to_s] << chunk
          yield chunk if block_given?
        end

        # Validate each group together
        chunk_groups.each do |chunk_type, chunks|
          validate_chunk_batch(chunk_type, chunks)

          # Early termination check after each batch
          break if @options[:fail_fast] && @context.has_errors?
        end
      end

      # Process chunks individually (original behavior)
      #
      # @return [void]
      def process_individual
        @reader.each_chunk do |chunk|
          validate_chunk(chunk)
          yield chunk if block_given?

          break if @options[:fail_fast] && @context.has_errors?
        end
      end

      # Process chunks in batch (performance optimization)
      #
      # Groups chunks by type and validates in batches to reduce
      # validator instantiation overhead.
      #
      # @param chunks [Array] Array of chunks to validate
      # @return [void]
      def process_batch(chunks)
        grouped = chunks.group_by { |c| c.chunk_type.to_s }

        grouped.each do |chunk_type, chunk_group|
          validate_chunk_batch(chunk_type, chunk_group)
        end
      end

      # Validate a single chunk
      #
      # Gets validator from pool for this chunk type from ChunkRegistry,
      # executes validation, and handles unknown chunks.
      #
      # @param chunk [Object] Chunk to validate
      # @return [void]
      def validate_chunk(chunk)
        chunk_type = chunk.chunk_type.to_s
        validator_class = Validators::ChunkRegistry.validator_for(chunk_type)

        if validator_class
          validator = @validator_pool.acquire(chunk_type, validator_class,
                                              chunk, @context)
          begin
            validator.validate
          ensure
            @validator_pool.release(chunk_type, validator)
          end
        else
          handle_unknown_chunk(chunk)
        end

        # Mark chunk as seen AFTER validation
        # This allows validators to check for duplicates before marking
        @context.mark_chunk_seen(chunk_type, chunk)
      end

      # Validate a batch of chunks of the same type
      #
      # Performance optimization: reduces validator instantiation
      # overhead by pooling validators for multiple chunks of same type.
      #
      # @param chunk_type [String] Type of chunks in batch
      # @param chunks [Array] Array of chunks of same type
      # @return [void]
      def validate_chunk_batch(chunk_type, chunks)
        validator_class = Validators::ChunkRegistry.validator_for(chunk_type)

        unless validator_class
          # No validator for this chunk type - handle as unknown
          chunks.each do |chunk|
            handle_unknown_chunk(chunk)
            @context.mark_chunk_seen(chunk.chunk_type.to_s, chunk)
          end
          return
        end

        chunks.each do |chunk|
          validator = @validator_pool.acquire(chunk_type, validator_class,
                                              chunk, @context)
          begin
            validator.validate
          ensure
            @validator_pool.release(chunk_type, validator)
          end
          @context.mark_chunk_seen(chunk_type, chunk)
        end
      end

      # Handle unknown chunk types
      #
      # Unknown chunks are checked for safety:
      # - If ancillary (bit 5 of first byte = 1), it's safe to ignore
      # - If critical (bit 5 = 0), it's an error
      #
      # @param chunk [Object] Unknown chunk
      # @return [void]
      def handle_unknown_chunk(chunk)
        chunk_type = chunk.chunk_type.to_s
        first_byte = chunk_type.bytes[0]

        # Bit 5 (0x20) of first byte indicates ancillary vs critical
        if (first_byte & 0x20).zero?
          # Critical chunk - must be recognized
          @context.add_error(
            chunk_type: chunk_type,
            message: "Unknown critical chunk type: #{chunk_type}",
            severity: :error,
            offset: chunk.abs_offset,
          )
        else
          # Ancillary chunk - safe to ignore
          @context.add_error(
            chunk_type: chunk_type,
            message: "Unknown ancillary chunk type: #{chunk_type} (ignored)",
            severity: :info,
            offset: chunk.abs_offset,
          )
        end
      end
    end
  end
end
