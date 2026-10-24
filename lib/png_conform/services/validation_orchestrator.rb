# frozen_string_literal: true

require_relative "../readers/chunk_framing"
require_relative "../readers/format_dispatch"
require_relative "chunk_processor"
require_relative "result_builder"
require_relative "analysis_manager"

module PngConform
  module Services
    # Main validation orchestration service
    #
    # This service coordinates the validation of PNG, MNG and JNG files by:
    # 1. Detecting the format from the file signature
    # 2. Processing chunks through ChunkProcessor
    # 3. Validating the detected format's chunk sequence requirements
    # 4. Building the complete FileAnalysis result
    #
    # The orchestrator follows a pipeline architecture:
    # File → Signature → Chunks → Sequence → Analysis → Result
    #
    class ValidationOrchestrator
      attr_reader :reader, :filepath, :options, :context, :chunks, :detected_format

      # Convenience method to validate a file by path
      #
      # @param filepath [String] Path to PNG file
      # @param options [Hash] Optional CLI options
      # @return [FileAnalysis] Complete file analysis
      def self.validate_file(filepath, options = {})
        require_relative "../readers/full_load_reader"
        reader = Readers::FullLoadReader.new(filepath)
        begin
          new(reader, filepath, options).validate
        ensure
          reader.close
        end
      end

      # Initialize validation orchestrator
      #
      # @param reader [Object] File reader (StreamingReader or FullLoadReader)
      # @param filepath [String, nil] Optional file path (for reporting)
      # @param options [Hash] CLI options for controlling behavior
      def initialize(reader, filepath = nil, options = {})
        @reader = reader
        @filepath = filepath
        @options = options
        @context = Validators::ValidationContext.new
        @chunks = []
        @detected_format = nil
      end

      # Validate the PNG file
      #
      # This is the main entry point for validation. It orchestrates
      # all validation stages in the correct order.
      #
      # @return [FileAnalysis] Complete file analysis with all data
      def validate
        validate_signature
        process_chunks
        validate_sequence
        build_result
      end

      # Get all errors from the validation context
      #
      # @return [Array<Hash>] Array of error hashes
      def errors
        @context.all_errors
      end

      # Get all warnings from the validation context
      #
      # @return [Array<Hash>] Array of warning hashes
      def warnings
        @context.all_warnings
      end

      # Get all info messages from the validation context
      #
      # @return [Array<Hash>] Array of info hashes
      def info_messages
        @context.all_info
      end

      private

      # Detect the file format from its signature
      #
      # Dispatches the 8-byte signature through FormatDispatch (PNG, MNG or
      # JNG) and records the detected format on the context. An unknown
      # signature gets its own cataloged diagnostic and no format, so no
      # format's required-chunk rules run against it.
      #
      # @return [void]
      def validate_signature
        sig = reader.signature
        @detected_format = Readers::FormatDispatch.detect(sig)
        @context.detected_format = @detected_format
        @context.store(:signature_checked, true)
        return if @detected_format

        @context.add_diagnostic(
          "all.signature.unknown",
          "Unrecognized file signature (not PNG, MNG or JNG)",
          chunk_type: "SIGNATURE", offset: 0, field: "signature",
          actual: sig.to_s.bytes.map { |b| format("%02x", b) }.join(" ")
        )
      end

      # Process all chunks using ChunkProcessor
      #
      # Delegates chunk validation to the ChunkProcessor which handles:
      # - Iterating through chunks
      # - Creating validators via ChunkRegistry
      # - Collecting validation results
      #
      # @return [void]
      def process_chunks
        processor = ChunkProcessor.new(@reader, @context, @options)
        processor.process do |chunk|
          @chunks << chunk
        end
        report_framing_error
      end

      # Report a declared chunk length the reader refused to read
      #
      # The reader stops before allocating for a length above the format
      # limit or beyond the remaining bytes, so the finding is identical on
      # every host.
      #
      # @return [void]
      def report_framing_error
        error = reader.framing_error if reader.respond_to?(:framing_error)
        return unless error

        detail = { offset: error.offset, chunk_index: error.chunk_index,
                   field: "length", actual: error.declared_length }
        if error.rule == :exceeds_limit
          @context.add_diagnostic(
            "all.chunk.length-exceeds-limit",
            "Chunk length #{error.declared_length} exceeds the maximum " \
            "#{Readers::ChunkFraming::MAX_LENGTH}",
            expected: "0-#{Readers::ChunkFraming::MAX_LENGTH}", **detail,
          )
        else
          @context.add_diagnostic(
            "all.chunk.length-exceeds-data",
            "Chunk length #{error.declared_length} exceeds the " \
            "#{error.available - Readers::ChunkFraming::CRC_BYTES} data " \
            "bytes remaining",
            expected: "0-#{error.available - Readers::ChunkFraming::CRC_BYTES}",
            **detail,
          )
        end
      end

      # Validate the detected format's top-level sequence requirements
      #
      # - PNG: IHDR first, IEND last, at least one IDAT
      # - MNG: MHDR first, MEND last
      # - JNG: JHDR first, IEND last, at least one JDAT
      #
      # An unrecognized signature has no sequence rules.
      #
      # @return [void]
      def validate_sequence
        case @detected_format&.key
        when :png then validate_png_sequence
        when :mng then validate_mng_sequence
        when :jng then validate_jng_sequence
        end
      end

      def validate_png_sequence
        index = chunk_index("IHDR")
        if index.nil?
          @context.add_diagnostic(
            "png.IHDR.missing", "Missing IHDR chunk (must be first)",
            chunk_type: "IHDR"
          )
        elsif index.positive?
          @context.add_diagnostic(
            "png.IHDR.first-chunk", "IHDR must be the first chunk",
            **located("IHDR", index)
          )
        end

        index = chunk_index("IEND", last: true)
        if index.nil?
          @context.add_diagnostic(
            "png.IEND.missing", "Missing IEND chunk (must be last)",
            chunk_type: "IEND"
          )
        elsif index != @chunks.size - 1
          @context.add_diagnostic(
            "png.IEND.last-chunk", "IEND must be the last chunk",
            **located("IEND", index)
          )
        end

        return if chunk_index("IDAT")

        @context.add_diagnostic(
          "png.IDAT.missing", "Missing IDAT chunk (at least one required)",
          chunk_type: "IDAT"
        )
      end

      def validate_mng_sequence
        index = chunk_index("MHDR")
        if index.nil?
          @context.add_diagnostic(
            "mng.MHDR.missing", "Missing MHDR chunk (must be first)",
            chunk_type: "MHDR"
          )
        elsif index.positive? && !reported?("mng.MHDR.first-chunk")
          @context.add_diagnostic(
            "mng.MHDR.first-chunk", "MHDR must be the first chunk in MNG file",
            **located("MHDR", index)
          )
        end

        index = chunk_index("MEND", last: true)
        if index.nil?
          @context.add_diagnostic(
            "mng.MEND.missing", "Missing MEND chunk (must be last)",
            chunk_type: "MEND"
          )
        elsif index != @chunks.size - 1
          @context.add_diagnostic(
            "mng.MEND.last-chunk", "MEND must be the last chunk",
            **located("MEND", index)
          )
        end
      end

      def validate_jng_sequence
        index = chunk_index("JHDR")
        if index.nil?
          @context.add_diagnostic(
            "jng.JHDR.missing", "Missing JHDR chunk (must be first)",
            chunk_type: "JHDR"
          )
        elsif index.positive? && !reported?("jng.JHDR.first-chunk")
          @context.add_diagnostic(
            "jng.JHDR.first-chunk",
            "JHDR must be the first chunk in JNG datastream",
            **located("JHDR", index),
          )
        end

        index = chunk_index("IEND", last: true)
        if index.nil?
          @context.add_diagnostic(
            "jng.IEND.missing", "Missing IEND chunk (must be last)",
            chunk_type: "IEND"
          )
        elsif index != @chunks.size - 1
          @context.add_diagnostic(
            "jng.IEND.last-chunk", "IEND must be the last chunk",
            **located("IEND", index)
          )
        end

        return if chunk_index("JDAT")

        @context.add_diagnostic(
          "jng.JDAT.missing", "Missing JDAT chunk (at least one required)",
          chunk_type: "JDAT"
        )
      end

      # Position of the first (or last) chunk of a type in file order
      #
      # @return [Integer, nil]
      def chunk_index(type, last: false)
        finder = last ? :rindex : :index
        @chunks.public_send(finder) { |c| c.chunk_type.to_s == type }
      end

      # Location detail for a chunk found at an unexpected position
      def located(type, index)
        { chunk_type: type, chunk_index: index,
          offset: @chunks[index].abs_offset }
      end

      # Whether a chunk validator already reported this requirement
      def reported?(id)
        @context.errors.any? { |e| e.requirement_id == id }
      end

      # Build complete FileAnalysis with validation results and analyzer data
      #
      # Coordinates ResultBuilder and AnalysisManager to produce the final result
      #
      # @return [FileAnalysis] Complete analysis model
      def build_result
        result_builder = ResultBuilder.new(@reader, @filepath, @context,
                                           @chunks, @options)
        file_analysis = result_builder.build

        # Run analyzers through AnalysisManager
        analysis_manager = AnalysisManager.new(@options)
        analysis_manager.enrich(file_analysis)

        file_analysis
      end
    end
  end
end
