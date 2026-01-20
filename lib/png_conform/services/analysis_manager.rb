# frozen_string_literal: true

require_relative "../configuration"

module PngConform
  module Services
    # Manages conditional analysis execution
    #
    # The AnalysisManager handles:
    # - Running resolution analysis (conditional)
    # - Running optimization analysis (conditional)
    # - Running metrics analysis (conditional)
    #
    # Analyzers are only run when needed based on options to improve performance.
    # This class extracts analysis logic from ValidationService following
    # Single Responsibility Principle.
    #
    class AnalysisManager
      # Initialize analysis manager
      #
      # @param options [Hash] CLI options for controlling behavior
      # @param config [Configuration] Configuration instance (optional)
      def initialize(options = {}, config: Configuration.instance)
        @options = options
        @config = config
      end

      # Enrich FileAnalysis with conditional analyzer results
      #
      # Runs analyzers only when needed based on options:
      # - Resolution analysis: unless quiet mode, or if --resolution or --mobile-ready
      # - Optimization analysis: unless quiet mode, or if --optimize
      # - Metrics analysis: if yaml/json format, or if --metrics
      #
      # @param file_analysis [FileAnalysis] File analysis to enrich
      # @return [FileAnalysis] Enriched file analysis
      def enrich(file_analysis)
        validation_result = file_analysis.validation_result

        if need_resolution_analysis?
          file_analysis.resolution_analysis =
            run_resolution_analysis(validation_result)
        end

        if need_optimization_analysis?
          file_analysis.optimization_analysis =
            run_optimization_analysis(validation_result)
        end

        if need_metrics_analysis?
          file_analysis.metrics = run_metrics_analysis(validation_result)
        end

        file_analysis
      end

      private

      # Run resolution analyzer
      #
      # @param result [ValidationResult] Validation result
      # @return [Hash] Resolution analysis results
      def run_resolution_analysis(result)
        require_relative "../analyzers/resolution_analyzer" unless defined?(Analyzers::ResolutionAnalyzer)
        Analyzers::ResolutionAnalyzer.new(result, config: @config).analyze
      rescue StandardError => e
        { error: "Resolution analysis failed: #{e.message}" }
      end

      # Run optimization analyzer
      #
      # @param result [ValidationResult] Validation result
      # @return [Hash] Optimization analysis results
      def run_optimization_analysis(result)
        require_relative "../analyzers/optimization_analyzer" unless defined?(Analyzers::OptimizationAnalyzer)
        Analyzers::OptimizationAnalyzer.new(result, config: @config).analyze
      rescue StandardError => e
        { error: "Optimization analysis failed: #{e.message}" }
      end

      # Run metrics analyzer
      #
      # @param result [ValidationResult] Validation result
      # @return [Hash] Metrics analysis results
      def run_metrics_analysis(result)
        require_relative "../analyzers/metrics_analyzer" unless defined?(Analyzers::MetricsAnalyzer)
        Analyzers::MetricsAnalyzer.new(result, config: @config).analyze
      rescue StandardError => e
        { error: "Metrics analysis failed: #{e.message}" }
      end

      # Check if resolution analysis is needed
      #
      # @return [Boolean] True if resolution analysis should be run
      def need_resolution_analysis?
        return true unless @options[:quiet]

        @options[:resolution] || @options[:mobile_ready]
      end

      # Check if optimization analysis is needed
      #
      # @return [Boolean] True if optimization analysis should be run
      def need_optimization_analysis?
        return true unless @options[:quiet]

        @options[:optimize]
      end

      # Check if metrics analysis is needed
      #
      # @return [Boolean] True if metrics analysis should be run
      def need_metrics_analysis?
        return true if ["yaml", "json"].include?(@options[:format])

        @options[:metrics]
      end
    end
  end
end
