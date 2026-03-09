# frozen_string_literal: true

require "zlib"

module PngConform
  module Services
    # Service for validating zlib compressed data streams
    #
    # This service handles:
    # - zlib stream decompression
    # - Filter type validation
    # - Scanline reconstruction
    # - Interlacing support (Adam7)
    # - Data integrity verification
    #
    # PNG uses zlib compression (RFC 1950) with deflate algorithm (RFC 1951)
    # for IDAT chunks. The decompressed data consists of filtered scanlines
    # that must be unfiltered to reconstruct the original image data.
    #
    class ZlibValidator
      # Filter types defined in PNG specification
      FILTER_NONE = 0
      FILTER_SUB = 1
      FILTER_UP = 2
      FILTER_AVERAGE = 3
      FILTER_PAETH = 4

      VALID_FILTERS = [FILTER_NONE, FILTER_SUB, FILTER_UP,
                       FILTER_AVERAGE, FILTER_PAETH].freeze

      attr_reader :errors, :warnings, :decompressed_data

      def initialize
        @errors = []
        @warnings = []
        @decompressed_data = nil
      end

      # Decompress and validate zlib compressed data
      #
      # @param compressed_data [String] Binary compressed data
      # @param expected_size [Integer, nil] Expected decompressed size
      # @return [Boolean] True if validation passed
      def decompress_and_validate(compressed_data, expected_size: nil)
        return false if compressed_data.nil? || compressed_data.empty?

        begin
          # Decompress using zlib
          @decompressed_data = Zlib::Inflate.inflate(compressed_data)

          # Validate decompressed size if expected size provided
          if expected_size && @decompressed_data.bytesize != expected_size
            add_error("Decompressed size mismatch " \
                      "(expected #{expected_size}, got #{@decompressed_data.bytesize})")
            return false
          end

          true
        rescue Zlib::Error => e
          add_error("zlib decompression error: #{e.message}")
          false
        rescue StandardError => e
          add_error("Unexpected error during decompression: #{e.message}")
          false
        end
      end

      # Validate filter bytes in scanlines
      #
      # @param width [Integer] Image width in pixels
      # @param height [Integer] Image height in pixels
      # @param bit_depth [Integer] Bits per sample
      # @param color_type [Integer] PNG color type
      # @param interlace_method [Integer] Interlace method (0 or 1)
      # @return [Boolean] True if all filters are valid
      def validate_filters(width, height, bit_depth, color_type,
                           interlace_method)
        return false unless @decompressed_data

        bytes_per_pixel = calculate_bytes_per_pixel(bit_depth, color_type)

        if interlace_method.zero?
          validate_non_interlaced_filters(width, height, bytes_per_pixel)
        elsif interlace_method == 1
          validate_adam7_filters(width, height, bytes_per_pixel)
        else
          add_error("Invalid interlace method: #{interlace_method}")
          false
        end
      end

      # Check if decompressed data size matches expected size
      #
      # @param width [Integer] Image width
      # @param height [Integer] Image height
      # @param bit_depth [Integer] Bits per sample
      # @param color_type [Integer] PNG color type
      # @param interlace_method [Integer] Interlace method
      # @return [Boolean] True if size matches
      def validate_data_size(width, height, bit_depth, color_type,
                             interlace_method)
        return false unless @decompressed_data

        expected = calculate_expected_size(width, height, bit_depth,
                                           color_type, interlace_method)
        actual = @decompressed_data.bytesize

        if actual != expected
          add_error("Decompressed data size mismatch " \
                    "(expected #{expected} bytes, got #{actual} bytes)")
          return false
        end

        true
      end

      # Get validation result
      #
      # @return [Hash] Validation result with status and messages
      def result
        {
          valid: @errors.empty?,
          errors: @errors,
          warnings: @warnings,
          decompressed_size: @decompressed_data&.bytesize,
        }
      end

      private

      def add_error(message)
        @errors << message
      end

      def add_warning(message)
        @warnings << message
      end

      # Calculate bytes per pixel
      def calculate_bytes_per_pixel(bit_depth, color_type)
        samples_per_pixel = case color_type
                            when 0 then 1  # Grayscale
                            when 2 then 3  # RGB
                            when 3 then 1  # Indexed
                            when 4 then 2  # Grayscale + Alpha
                            when 6 then 4  # RGB + Alpha
                            else 0
                            end

        # Bytes per pixel (rounded up)
        (((samples_per_pixel * bit_depth) + 7) / 8.0).ceil
      end

      # Calculate expected decompressed data size
      def calculate_expected_size(width, height, bit_depth, color_type,
                                  interlace_method)
        bytes_per_pixel = calculate_bytes_per_pixel(bit_depth, color_type)

        if interlace_method.zero?
          # Non-interlaced: (scanline_width + 1 filter byte) * height
          scanline_width = (((width * bit_depth * samples_for_color_type(color_type)) + 7) / 8.0).ceil
          (scanline_width + 1) * height
        else
          # Adam7 interlaced: calculate for all 7 passes
          calculate_adam7_size(width, height, bytes_per_pixel)
        end
      end

      def samples_for_color_type(color_type)
        case color_type
        when 0 then 1  # Grayscale
        when 2 then 3  # RGB
        when 3 then 1  # Indexed
        when 4 then 2  # Grayscale + Alpha
        when 6 then 4  # RGB + Alpha
        else 0
        end
      end

      # Validate filters for non-interlaced image
      def validate_non_interlaced_filters(width, height, bytes_per_pixel)
        offset = 0
        scanline_width = width * bytes_per_pixel

        height.times do |row|
          break if offset >= @decompressed_data.bytesize

          filter_type = @decompressed_data[offset].ord

          unless VALID_FILTERS.include?(filter_type)
            add_error("Invalid filter type #{filter_type} at scanline #{row}")
            return false
          end

          offset += scanline_width + 1 # +1 for filter byte
        end

        true
      end

      # Validate filters for Adam7 interlaced image
      def validate_adam7_filters(width, height, bytes_per_pixel)
        # Adam7 interlacing uses 7 passes with different starting positions and steps
        adam7_passes = [
          { x_start: 0, y_start: 0, x_step: 8, y_step: 8 },
          { x_start: 4, y_start: 0, x_step: 8, y_step: 8 },
          { x_start: 0, y_start: 4, x_step: 4, y_step: 8 },
          { x_start: 2, y_start: 0, x_step: 4, y_step: 4 },
          { x_start: 0, y_start: 2, x_step: 2, y_step: 4 },
          { x_start: 1, y_start: 0, x_step: 2, y_step: 2 },
          { x_start: 0, y_start: 1, x_step: 1, y_step: 2 },
        ]

        offset = 0

        adam7_passes.each_with_index do |pass, pass_num|
          pass_width = ((width - pass[:x_start] + pass[:x_step] - 1) / pass[:x_step]).floor
          pass_height = ((height - pass[:y_start] + pass[:y_step] - 1) / pass[:y_step]).floor

          next if pass_width.zero? || pass_height.zero?

          scanline_width = pass_width * bytes_per_pixel

          pass_height.times do |row|
            break if offset >= @decompressed_data.bytesize

            filter_type = @decompressed_data[offset].ord

            unless VALID_FILTERS.include?(filter_type)
              add_error("Invalid filter type #{filter_type} " \
                        "at pass #{pass_num}, scanline #{row}")
              return false
            end

            offset += scanline_width + 1
          end
        end

        true
      end

      # Calculate expected size for Adam7 interlaced image
      def calculate_adam7_size(width, height, bytes_per_pixel)
        adam7_passes = [
          { x_start: 0, y_start: 0, x_step: 8, y_step: 8 },
          { x_start: 4, y_start: 0, x_step: 8, y_step: 8 },
          { x_start: 0, y_start: 4, x_step: 4, y_step: 8 },
          { x_start: 2, y_start: 0, x_step: 4, y_step: 4 },
          { x_start: 0, y_start: 2, x_step: 2, y_step: 4 },
          { x_start: 1, y_start: 0, x_step: 2, y_step: 2 },
          { x_start: 0, y_start: 1, x_step: 1, y_step: 2 },
        ]

        total_size = 0

        adam7_passes.each do |pass|
          pass_width = ((width - pass[:x_start] + pass[:x_step] - 1) / pass[:x_step]).floor
          pass_height = ((height - pass[:y_start] + pass[:y_step] - 1) / pass[:y_step]).floor

          next if pass_width.zero? || pass_height.zero?

          scanline_width = pass_width * bytes_per_pixel
          total_size += (scanline_width + 1) * pass_height
        end

        total_size
      end
    end
  end
end
