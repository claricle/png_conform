# frozen_string_literal: true

require_relative "lru_cache"
require "digest"

module PngConform
  module Services
    # Validation cache for storing and reusing validation results
    #
    # Provides multi-level caching for validation operations to avoid
    # redundant I/O and computation. Supports LRU eviction for memory efficiency.
    #
    class ValidationCache
      attr_reader :file_cache, :max_files, :enabled

      # Default configuration
      DEFAULT_MAX_FILES = 100
      DEFAULT_ENABLED = true

      class << self
        # Get global singleton instance
        #
        # @return [ValidationCache] Global cache instance
        def instance
          @instance ||= new
        end

        # Reset global cache
        #
        # @return [void]
        def reset!
          @instance = new
        end
      end

      # Initialize validation cache
      #
      # @param options [Hash] Cache configuration options
      def initialize(options = {})
        @max_files = options.fetch(:max_files, DEFAULT_MAX_FILES)
        @file_cache = LRUCache.new(@max_files)
        @enabled = options.fetch(:enabled, DEFAULT_ENABLED)
        @stats = {
          hits: 0,
          misses: 0,
          evictions: 0,
        }
      end

      # Fetch cached validation result for a file
      #
      # @param file_path [String] Path to PNG file
      # @param options [Hash] Validation options (affects cache key)
      # @return [FileAnalysis, nil] Cached result or nil if not cached
      def fetch(file_path, options = {})
        return nil unless @enabled

        cache_key = generate_cache_key(file_path, options)
        entry = @file_cache[cache_key]

        if entry
          @stats[:hits] += 1
          # Return shallow copy - FileAnalysis objects are read-only after creation
          # This is significantly faster than Marshal deep copy
          shallow_copy(entry[:result])
        else
          @stats[:misses] += 1
          nil
        end
      end

      # Store validation result in cache
      #
      # @param file_path [String] Path to PNG file
      # @param options [Hash] Validation options (affects cache key)
      # @param result [FileAnalysis] Validation result to cache
      # @return [void]
      def store(file_path, options, result)
        return unless @enabled

        cache_key = generate_cache_key(file_path, options)
        entry = {
          result: result, # Store reference - objects are read-only
          timestamp: Time.now,
          file_size: result.file_size,
          validation_time: result.validation_result&.validation_time,
        }

        @file_cache[cache_key] = entry
      end

      # Check if file validation is cached
      #
      # @param file_path [String] Path to PNG file
      # @param options [Hash] Validation options
      # @return [Boolean] True if result is cached
      def cached?(file_path, options = {})
        return false unless @enabled

        cache_key = generate_cache_key(file_path, options)
        @file_cache.key?(cache_key)
      end

      # Invalidate cache entry for a file
      #
      # @param file_path [String] Path to PNG file
      # @param options [Hash] Validation options (optional)
      # @return [Boolean] True if entry was found and removed
      def invalidate(file_path, options = {})
        return false unless @enabled

        cache_key = generate_cache_key(file_path, options)
        deleted = @file_cache.delete(cache_key)

        if deleted
          @stats[:evictions] += 1
        end

        !!deleted
      end

      # Clear all cached entries
      #
      # @return [void]
      def clear
        @file_cache.clear
        reset_stats
      end

      # Get cache statistics
      #
      # @return [Hash] Cache performance statistics
      def stats
        total_requests = @stats[:hits] + @stats[:misses]
        hit_rate = if total_requests.positive?
                     (@stats[:hits].to_f / total_requests * 100).round(1)
                   else
                     0.0
                   end

        {
          enabled: @enabled,
          max_files: @max_files,
          current_files: @file_cache.current_size,
          hits: @stats[:hits],
          misses: @stats[:misses],
          evictions: @stats[:evictions],
          hit_rate: hit_rate,
          cache_stats: @file_cache.stats,
        }
      end

      # Reset statistics counters
      #
      # @return [void]
      def reset_stats
        @stats = {
          hits: 0,
          misses: 0,
          evictions: 0,
        }
      end

      # Get cache key for file validation
      #
      # The cache key includes file path, mtime, and relevant options
      # to ensure cache validity when files change or options differ.
      #
      # @param file_path [String] Path to PNG file
      # @param options [Hash] Validation options
      # @return [String] Cache key
      def generate_cache_key(file_path, options = {})
        # Include relevant options in cache key
        relevant_opts = options.slice(:profile, :batch_enabled, :fail_fast)

        # Get file modification time for cache invalidation
        mtime = begin
          File.mtime(file_path).to_i
        rescue StandardError
          0
        end

        # Create deterministic cache key
        key_parts = [
          file_path,
          mtime,
          relevant_opts.sort.to_h,
        ]

        Digest::SHA256.hexdigest(key_parts.flatten.join(":"))
      end

      private

      # Create shallow copy of result object
      #
      # Uses .dup for fast shallow copying. FileAnalysis objects are
      # effectively read-only after creation, so deep copying is unnecessary.
      #
      # @param obj [Object] Object to copy
      # @return [Object] Shallow copy of object
      def shallow_copy(obj)
        obj.dup
      rescue TypeError
        # For objects that can't be dup'd, return as-is
        obj
      end
    end
  end
end
