# frozen_string_literal: true

module PngConform
  module Services
    # LRU (Least Recently Used) Cache implementation
    #
    # Provides efficient caching with automatic eviction of least recently
    # used items when capacity is reached. Thread-safe for basic operations.
    #
    class LRUCache
      attr_reader :max_size, :current_size

      # Initialize LRU cache
      #
      # @param max_size [Integer] Maximum number of items to store
      # @param options [Hash] Additional options
      def initialize(max_size, options = {})
        @max_size = max_size
        @cache = {}
        @order = [] # Tracks access order (most recent at end)
        @current_size = 0
        @thread_safe = options[:thread_safe] || false
        @mutex = @thread_safe ? Mutex.new : nil
      end

      # Get value for key
      #
      # @param key [Object] Cache key
      # @return [Object, nil] Cached value or nil if not found
      def [](key)
        return @cache[key] if @thread_safe && !@mutex.synchronize do
          @cache.key?(key)
        end

        with_synchronization do
          return nil unless @cache.key?(key)

          # Move to end (most recently used)
          @order.delete(key)
          @order.push(key)

          @cache[key]
        end
      end

      # Set value for key
      #
      # @param key [Object] Cache key
      # @param value [Object] Value to cache
      # @return [Object] The cached value
      def []=(key, value)
        with_synchronization do
          # Remove existing key if updating (to re-insert at end)
          @order.delete(key) if @cache.key?(key)

          @cache[key] = value
          @order.push(key)

          # Evict oldest if over capacity
          if @order.size > @max_size
            oldest = @order.shift
            @cache.delete(oldest)
          end

          @current_size = @cache.size
        end

        value
      end

      # Check if key exists
      #
      # @param key [Object] Cache key
      # @return [Boolean] True if key exists in cache
      def key?(key)
        @cache.key?(key)
      end

      # Check if cache is empty
      #
      # @return [Boolean] True if cache has no items
      def empty?
        @cache.empty?
      end

      # Clear all cached items
      #
      # @return [void]
      def clear
        with_synchronization do
          @cache.clear
          @order.clear
          @current_size = 0
        end
      end

      # Get all keys
      #
      # @return [Array<Object>] All cached keys (in LRU order)
      def keys
        @order.dup # Return copy to avoid external modification
      end

      # Get cache statistics
      #
      # @return [Hash] Cache statistics
      def stats
        {
          size: @cache.size,
          max_size: @max_size,
          usage_percent: ((@cache.size.to_f / @max_size) * 100).round(1),
        }
      end

      # Delete a specific key
      #
      # @param key [Object] Cache key to delete
      # @return [Object, nil] Deleted value or nil if not found
      def delete(key)
        with_synchronization do
          @order.delete(key)
          @cache.delete(key)
          @current_size = @cache.size
        end
      end

      # Peek at value without affecting LRU order
      #
      # @param key [Object] Cache key
      # @return [Object, nil] Cached value or nil if not found
      def peek(key)
        @cache[key]
      end

      # Get most recently used item
      #
      # @return [Array] [key, value] or nil if empty
      def mru
        return nil if @order.empty?

        key = @order.last
        [key, @cache[key]]
      end

      # Get least recently used item
      #
      # @return [Array] [key, value] or nil if empty
      def lru
        return nil if @order.empty?

        key = @order.first
        [key, @cache[key]]
      end

      private

      # Execute block with optional synchronization
      #
      # @yield Block to execute
      # @return [Object] Block result
      def with_synchronization(&block)
        if @thread_safe && @mutex
          @mutex.synchronize(&block)
        else
          yield
        end
      end
    end
  end
end
