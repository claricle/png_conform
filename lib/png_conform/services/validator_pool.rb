# frozen_string_literal: true

module PngConform
  module Services
    # Validator pool for reusing validator instances
    #
    # Reduces object allocation overhead by pooling validator instances
    # across chunk validations. Validators are reset between uses to ensure
    # clean state for each validation.
    #
    # This pool is scoped to a single validation session and should be
    # discarded after validation completes.
    #
    class ValidatorPool
      # Initialize validator pool
      #
      # @param options [Hash] Pool options
      # @option options [Integer] :max_per_type Maximum validators to cache per type
      def initialize(options = {})
        @max_per_type = options.fetch(:max_per_type, 5)
        @pools = {} # chunk_type => [validator instances]
        @stats = {
          created: 0,
          reused: 0,
          resets: 0,
        }
      end

      # Acquire a validator for the given chunk type
      #
      # Returns a validator from the pool if available, or creates a new one.
      # The validator is reset before being returned.
      #
      # @param chunk_type [String] Chunk type code
      # @param validator_class [Class] Validator class to instantiate
      # @param chunk [Object] Chunk object
      # @param context [ValidationContext] Validation context
      # @return [Object] Validator instance
      def acquire(chunk_type, validator_class, chunk, context)
        pool = pool_for(chunk_type)

        # Try to get a validator from the pool
        validator = pool.pop

        if validator
          @stats[:reused] += 1
          reset_validator(validator, chunk, context)
        else
          @stats[:created] += 1
          validator = validator_class.new(chunk, context)
        end

        validator
      end

      # Return a validator to the pool
      #
      # @param chunk_type [String] Chunk type code
      # @param validator [Object] Validator instance to return
      # @return [void]
      def release(chunk_type, validator)
        pool = pool_for(chunk_type)

        # Only pool if under limit
        if pool.size < @max_per_type
          # Clear validator state before returning to pool
          clear_validator(validator)
          pool << validator
        end
        # If pool is full, just let validator be garbage collected
      end

      # Clear all pools
      #
      # @return [void]
      def clear
        @pools.clear
        reset_stats
      end

      # Get pool statistics
      #
      # @return [Hash] Statistics about pool usage
      def stats
        pool_sizes = @pools.transform_values(&:size)
        @stats.merge(pool_sizes: pool_sizes,
                     total_pooled: pool_sizes.values.sum)
      end

      # Reset statistics
      #
      # @return [void]
      def reset_stats
        @stats = {
          created: 0,
          reused: 0,
          resets: 0,
        }
      end

      private

      # Get or create pool for a chunk type
      #
      # @param chunk_type [String] Chunk type code
      # @return [Array] Pool array for this chunk type
      def pool_for(chunk_type)
        @pools[chunk_type] ||= []
      end

      # Reset validator for reuse with new chunk and context
      #
      # @param validator [Object] Validator instance
      # @param chunk [Object] New chunk object
      # @param context [ValidationContext] New validation context
      # @return [void]
      def reset_validator(validator, chunk, context)
        @stats[:resets] += 1

        # Reset the validator's chunk and context
        validator.instance_variable_set(:@chunk, chunk)
        validator.instance_variable_set(:@context, context)

        # Clear any cached results/errors
        clear_validator(validator)
      end

      # Clear validator state
      #
      # @param validator [Object] Validator instance
      # @return [void]
      def clear_validator(validator)
        # Clear common instance variables that validators might cache
        validator.remove_instance_variable(:@errors) if validator.instance_variable_defined?(:@errors)
        validator.remove_instance_variable(:@warnings) if validator.instance_variable_defined?(:@warnings)
        validator.remove_instance_variable(:@info) if validator.instance_variable_defined?(:@info)
      rescue NameError
        # Variable doesn't exist, that's fine
      end
    end
  end
end
