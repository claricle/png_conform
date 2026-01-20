# frozen_string_literal: true

require_relative "readers/streaming_reader"
require_relative "services/profile_manager"
require_relative "services/analysis_manager"

module PngConform
  # Dependency Injection Container
  #
  # Centralized dependency management for the application.
  # Provides factory methods for creating readers, validators, reporters,
  # and other services with proper dependency injection.
  #
  # This makes testing easier by allowing mock injection and provides
  # a single source of truth for object creation.
  #
  class Container
    class << self
      # Create a reader for the given type and filepath
      #
      # @param type [Symbol] Reader type (:streaming or :full_load)
      # @param filepath [String] Path to PNG file
      # @param options [Hash] Additional options for the reader
      # @return [Object] Reader instance
      def reader(type, filepath, options = {})
        case type
        when :streaming
          io = File.open(filepath, "rb")
          Readers::StreamingReader.new(io, options)
        when :full_load
          Readers::FullLoadReader.new(filepath, options)
        else
          raise ArgumentError, "Unknown reader type: #{type}"
        end
      end

      # Open a reader with automatic file closing
      #
      # @param type [Symbol] Reader type (:streaming or :full_load)
      # @param filepath [String] Path to PNG file
      # @param options [Hash] Additional options for the reader
      # @yield [reader] Reader instance
      # @return [Object] Result of the block
      def open_reader(type, filepath, _options = {}, &block)
        case type
        when :streaming
          Readers::StreamingReader.open(filepath, &block)
        when :full_load
          Readers::FullLoadReader.open(filepath, &block)
        else
          raise ArgumentError, "Unknown reader type: #{type}"
        end
      end

      # Create a validator for a chunk
      #
      # Delegates to ChunkRegistry for validator creation
      #
      # @param chunk [Object] Chunk object
      # @param context [ValidationContext] Validation context
      # @return [Object] Validator instance or nil
      def validator(chunk, context)
        require_relative "validators/chunk_registry"
        Validators::ChunkRegistry.create_validator(chunk, context)
      end

      # Create a reporter based on options
      #
      # Delegates to ReporterFactory for reporter creation
      #
      # @param options [Hash] Reporter options
      # @return [Object] Reporter instance
      def reporter(options)
        require_relative "reporters/reporter_factory"
        Reporters::ReporterFactory.create(**options)
      end

      # Get the profile manager singleton
      #
      # @return [ProfileManager] Profile manager instance
      def profile_manager
        @profile_manager ||= Services::ProfileManager.new
      end

      # Create an analysis manager
      #
      # @param options [Hash] Analysis options
      # @return [AnalysisManager] Analysis manager instance
      def analysis_manager(options = {})
        Services::AnalysisManager.new(options)
      end

      # Create a validation orchestrator
      #
      # @param reader [Object] File reader
      # @param filepath [String] File path
      # @param options [Hash] Validation options
      # @return [ValidationOrchestrator] Orchestrator instance
      def validation_orchestrator(reader, filepath = nil, options = {})
        require_relative "services/validation_orchestrator"
        Services::ValidationOrchestrator.new(reader, filepath, options)
      end
      alias_method :validation_service, :validation_orchestrator

      # Reset container state
      #
      # Clears cached instances (useful for testing)
      def reset!
        @profile_manager = nil
      end
    end
  end
end
