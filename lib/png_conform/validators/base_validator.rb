# frozen_string_literal: true

require "lutaml/model"

module PngConform
  module Validators
    # Base class for all chunk validators
    #
    # Validators follow a consistent pattern:
    # 1. Initialize with chunk and context
    # 2. Validate method returns ValidationResult
    # 3. Protected helper methods for specific checks
    #
    # Validators are MECE - each handles exactly one chunk type
    # and validates all aspects of that chunk type completely.
    class BaseValidator
      attr_reader :chunk, :context

      # Initialize validator with chunk and validation context
      #
      # @param chunk [BinData::Record] The chunk to validate
      # @param context [ValidationContext] The validation context
      def initialize(chunk, context = nil)
        @chunk = chunk
        @context = context || ValidationContext.new
      end

      # Validate the chunk
      #
      # @return [ValidationResult] The validation result
      def validate
        raise NotImplementedError, "Subclasses must implement #validate"
      end

      protected

      # Add an error to the validation result
      #
      # @param message [String] The error message
      # @param severity [Symbol] :error, :warning, or :info
      def add_error(message, severity: :error)
        context.add_error(
          chunk_type: chunk.chunk_type,
          message: message,
          severity: severity,
          offset: chunk.abs_offset,
        )
      end

      # Add a warning to the validation result
      #
      # @param message [String] The warning message
      def add_warning(message)
        add_error(message, severity: :warning)
      end

      # Add an info message to the validation result
      #
      # @param message [String] The info message
      def add_info(message)
        add_error(message, severity: :info)
      end

      # Check if chunk data length matches expected length
      #
      # @param expected [Integer] Expected data length
      # @return [Boolean] True if length matches
      def check_length(expected)
        actual = chunk.chunk_data.length
        return true if actual == expected

        add_error("invalid #{chunk.chunk_type} length (#{actual}, " \
                  "should be #{expected})")
        false
      end

      # Check if value is within valid range
      #
      # @param value [Integer] Value to check
      # @param min [Integer] Minimum valid value
      # @param max [Integer] Maximum valid value
      # @param name [String] Name of the value for error message
      # @return [Boolean] True if value is in range
      def check_range(value, min, max, name)
        return true if value >= min && value <= max

        add_error("invalid #{name} (#{value}, must be #{min}-#{max})")
        false
      end

      # Check if value is one of valid options
      #
      # @param value [Object] Value to check
      # @param valid [Array] Array of valid values
      # @param name [String] Name of the value for error message
      # @return [Boolean] True if value is valid
      def check_enum(value, valid, name)
        return true if valid.include?(value)

        add_error("invalid #{name} (#{value}, must be one of " \
                  "#{valid.join(', ')})")
        false
      end

      # Check if chunk CRC is valid
      #
      # @return [Boolean] True if CRC is valid
      def check_crc
        return true if chunk.crc_valid?

        add_error("CRC error in #{chunk.chunk_type} chunk")
        false
      end
    end

    # Validation context maintains state during validation
    class ValidationContext
      attr_reader :errors, :chunks_seen, :file_info

      def initialize
        @errors = []
        @chunks_seen = {}
        @file_info = {}
      end

      # Add an error/warning/info to the context
      #
      # @param chunk_type [String] The chunk type
      # @param message [String] The error message
      # @param severity [Symbol] :error, :warning, or :info
      # @param offset [Integer] File offset of the error
      def add_error(chunk_type:, message:, severity: :error, offset: nil)
        @errors << {
          chunk_type: chunk_type,
          message: message,
          severity: severity,
          offset: offset,
        }
      end

      # Record that a chunk type has been seen
      #
      # @param chunk_type [String] The chunk type
      # @param chunk [BinData::Record] The chunk
      def record_chunk(chunk_type, chunk = nil)
        @chunks_seen[chunk_type] ||= []
        @chunks_seen[chunk_type] << chunk if chunk
      end
      alias mark_chunk_seen record_chunk

      # Check if a chunk type has been seen
      #
      # @param chunk_type [String] The chunk type
      # @return [Boolean] True if chunk type has been seen
      def seen?(chunk_type)
        @chunks_seen.key?(chunk_type)
      end

      # Get chunks of a specific type
      #
      # @param chunk_type [String] The chunk type
      # @return [Array] Array of chunks of that type
      def chunks_of_type(chunk_type)
        @chunks_seen[chunk_type] || []
      end

      # Store file information
      #
      # @param key [Symbol] The key
      # @param value [Object] The value
      def store(key, value)
        @file_info[key] = value
      end

      # Retrieve file information
      #
      # @param key [Symbol] The key
      # @return [Object] The value
      def retrieve(key)
        @file_info[key]
      end

      # Check if validation has errors
      #
      # @return [Boolean] True if there are any errors
      def has_errors?
        @errors.any? { |e| e[:severity] == :error }
      end

      # Check if validation has warnings
      #
      # @return [Boolean] True if there are any warnings
      def has_warnings?
        @errors.any? { |e| e[:severity] == :warning }
      end

      # Get all errors
      #
      # @return [Array] Array of error hashes
      def all_errors
        @errors.select { |e| e[:severity] == :error }
      end

      # Get all warnings
      #
      # @return [Array] Array of warning hashes
      def all_warnings
        @errors.select { |e| e[:severity] == :warning }
      end

      # Get all info messages
      #
      # @return [Array] Array of info hashes
      def all_info
        @errors.select { |e| e[:severity] == :info }
      end

      # Provide attribute-style access to file_info
      #
      # Allows context.width instead of context.retrieve(:width)
      # and context.width = 100 instead of context.store(:width, 100)
      def method_missing(method, *args)
        method_name = method.to_s
        if method_name.end_with?("=")
          # Setter: context.width = 100
          key = method_name.chomp("=").to_sym
          store(key, args.first)
        elsif args.empty?
          # Getter: context.width
          retrieve(method.to_sym)
        else
          super
        end
      end

      def respond_to_missing?(_method, _include_private = false)
        true
      end
    end
  end
end
