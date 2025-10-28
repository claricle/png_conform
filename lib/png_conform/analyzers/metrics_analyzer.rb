# frozen_string_literal: true

module PngConform
  module Analyzers
    # Generates comprehensive metrics for CI/CD and automation
    class MetricsAnalyzer
      # Text chunk types
      TEXT_CHUNKS = %w[tEXt zTXt iTXt].freeze

      # Metadata chunk types including time
      METADATA_CHUNKS = %w[tEXt zTXt iTXt tIME].freeze

      def initialize(result)
        @result = result
        ihdr = result.ihdr_chunk
        @width = ihdr ? get_width(ihdr) : 0
        @height = ihdr ? get_height(ihdr) : 0
        @bit_depth = ihdr ? get_bit_depth(ihdr) : 0
        @color_type = ihdr ? get_color_type(ihdr) : 0
      end

      def analyze
        {
          file: file_metrics,
          image: image_metrics,
          chunks: chunk_metrics,
          validation: validation_metrics,
          compression: compression_metrics,
          quality: quality_metrics,
        }
      end

      def to_json(*_args)
        require "json"
        JSON.pretty_generate(analyze)
      end

      def to_yaml
        require "yaml"
        analyze.to_yaml
      end

      private

      # Extract data from IHDR chunk
      def get_width(ihdr_chunk)
        return 0 unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 4

        ihdr_chunk.data.bytes[0..3].pack("C*").unpack1("N")
      end

      def get_height(ihdr_chunk)
        return 0 unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 8

        ihdr_chunk.data.bytes[4..7].pack("C*").unpack1("N")
      end

      def get_bit_depth(ihdr_chunk)
        return 0 unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 9

        ihdr_chunk.data.bytes[8]
      end

      def get_color_type(ihdr_chunk)
        return 0 unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 10

        ihdr_chunk.data.bytes[9]
      end

      def color_type_name
        case @color_type
        when 0 then "Grayscale"
        when 2 then "RGB"
        when 3 then "Indexed"
        when 4 then "Grayscale+Alpha"
        when 6 then "RGBA"
        else "Unknown"
        end
      end

      def file_metrics
        {
          filename: @result.filename,
          size_bytes: @result.file_size,
          size_kb: (@result.file_size / 1024.0).round(2),
          size_mb: (@result.file_size / 1024.0 / 1024.0).round(4),
          file_type: @result.file_type,
        }
      end

      def image_metrics
        {
          width: @width,
          height: @height,
          dimensions: "#{@width}x#{@height}",
          total_pixels: @width * @height,
          megapixels: (@width * @height / 1_000_000.0).round(2),
          bit_depth: @bit_depth,
          color_type: @color_type,
          color_type_name: color_type_name,
          has_alpha: [4, 6].include?(@color_type),
          has_palette: @color_type == 3,
        }
      end

      def chunk_metrics
        {
          total_count: @result.chunks.count,
          types: @result.chunks.map(&:type).uniq.sort,
          type_counts: @result.chunks.group_by(&:type).transform_values(&:count),
          critical_chunks: @result.chunks.select(&:critical?).map(&:type),
          ancillary_chunks: @result.chunks.reject(&:critical?).map(&:type),
          total_chunk_data_bytes: @result.chunks.sum(&:length),
          total_chunk_overhead_bytes: @result.chunks.count * 12,
          chunk_data_percentage: calculate_chunk_data_percentage,
        }
      end

      def validation_metrics
        {
          valid: @result.valid?,
          error_count: @result.error_count,
          warning_count: @result.warning_count,
          info_count: @result.info_count,
          errors_by_severity: {
            error: @result.error_count,
            warning: @result.warning_count,
            info: @result.info_count,
          },
          crc_errors: @result.crc_errors_count,
          has_errors: @result.error_count.positive?,
          has_warnings: @result.warning_count.positive?,
        }
      end

      def compression_metrics
        {
          compression_ratio: @result.compression_ratio,
        }
      end

      def quality_metrics
        {
          has_color_profile: @result.has_chunk?("gAMA") ||
            @result.has_chunk?("sRGB") ||
            @result.has_chunk?("iCCP"),
          has_gamma: @result.has_chunk?("gAMA"),
          has_srgb: @result.has_chunk?("sRGB"),
          has_iccp: @result.has_chunk?("iCCP"),
          has_transparency: @result.has_chunk?("tRNS"),
          has_metadata: @result.chunks.any? { |c| TEXT_CHUNKS.include?(c.type) },
          metadata_chunks_count: @result.chunks.count { |c| METADATA_CHUNKS.include?(c.type) },
          bytes_per_pixel: calculate_bytes_per_pixel,
        }
      end

      def calculate_chunk_data_percentage
        return 0 if @result.file_size.zero?

        total_chunk_bytes = @result.chunks.sum(&:length) + (@result.chunks.count * 12)
        (total_chunk_bytes.to_f / @result.file_size * 100).round(2)
      end

      def calculate_bytes_per_pixel
        total_pixels = @width * @height
        return 0 if total_pixels.zero?

        (@result.file_size.to_f / total_pixels).round(3)
      end
    end
  end
end
