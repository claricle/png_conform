# frozen_string_literal: true

module PngConform
  # Application configuration
  #
  # Centralized configuration for all hardcoded values across the codebase.
  # Provides a single source of truth for constants and settings.
  #
  class Configuration
    attr_accessor :retina_densities, :print_dpi_thresholds,
                  :network_speeds, :optimization_thresholds,
                  :color_enabled, :screen_dpi, :css_reference_dpi,
                  :retina_scalers, :unnecessary_web_chunks,
                  :text_chunks, :metadata_chunks,
                  :optimization_percentages, :size_thresholds

    class << self
      # Get the singleton instance
      #
      # @return [Configuration] Configuration instance
      def instance
        @instance ||= new
      end

      # Reset configuration to defaults
      #
      # @return [void]
      def reset!
        @instance = new
      end
    end

    # Initialize configuration with defaults
    #
    def initialize
      # Retina display densities (Android buckets)
      @retina_densities = {
        mdpi: 160,
        hdpi: 320,
        xhdpi: 480,
        xxhdpi: 640,
      }

      # Print DPI quality thresholds
      @print_dpi_thresholds = {
        minimum: 150,
        good: 300,
        excellent: 600,
      }

      # Network speeds for load time estimation (bytes per second)
      @network_speeds = {
        slow: 1_000_000, # 1 Mbps
        fast: 10_000_000, # 10 Mbps
      }

      # Optimization percentage thresholds
      @optimization_thresholds = {
        high_savings: 30, # 30%
        medium_savings: 10, # 10%
      }

      # Color output enabled
      @color_enabled = true

      # Screen DPI constants
      @screen_dpi = 72

      # CSS reference DPI for Retina calculations
      @css_reference_dpi = 163

      # Retina display scaling factors
      @retina_scalers = {
        "1x": 1.0,
        "2x": 2.0,
        "3x": 3.0,
      }

      # Chunks unnecessary for web/mobile use
      @unnecessary_web_chunks = %w[tIME pHYs oFFs pCAL sCAL sTER].freeze

      # Text chunk types
      @text_chunks = %w[tEXt zTXt iTXt].freeze

      # Metadata chunk types
      @metadata_chunks = %w[tEXt zTXt iTXt tIME pHYs].freeze

      # Optimization savings percentages
      @optimization_percentages = {
        bit_depth_reduction: 45, # % savings for 16->8 bit
        palette_conversion: 30,    # % savings for RGB->palette
        interlace_removal: 15,     # % savings for removing interlace
        metadata_threshold: 10, # % of file size to flag excessive metadata
      }

      # Size thresholds
      @size_thresholds = {
        palette_opportunity: 10_000, # bytes - min file size to suggest palette
        text_metadata: 500,          # bytes - min text metadata size to flag
        small_file: 100_000,         # bytes - file size considered "small"
        retina_ready_min: 88,        # pixels - min dimension for retina ready
        very_large: 3000,            # pixels - dimension considered "very large"
        large_for_mobile: 1920,      # pixels - max dimension for mobile friendly
        large_for_web: 4096, # pixels - max dimension for web suitable
      }
    end

    # Get density value by name
    #
    # @param name [Symbol] Density name (:mdpi, :hdpi, :xhdpi, :xxhdpi)
    # @return [Integer] DPI value
    def retina_density(name)
      @retina_densities[name] || @retina_densities[:hdpi]
    end

    # Get print DPI threshold by name
    #
    # @param name [Symbol] Threshold name (:minimum, :good, :excellent)
    # @return [Integer] DPI value
    def print_dpi_threshold(name)
      @print_dpi_thresholds[name] || @print_dpi_thresholds[:good]
    end

    # Get network speed by name
    #
    # @param name [Symbol] Speed name (:slow, :fast)
    # @return [Integer] Bytes per second
    def network_speed(name)
      @network_speeds[name] || @network_speeds[:fast]
    end

    # Get optimization threshold by name
    #
    # @param name [Symbol] Threshold name (:high_savings, :medium_savings)
    # @return [Integer] Percentage threshold
    def optimization_threshold(name)
      @optimization_thresholds[name] || @optimization_thresholds[:medium_savings]
    end

    # Check if colors are enabled
    #
    # @return [Boolean] true if colors are enabled
    def color_enabled?
      @color_enabled
    end
  end
end
