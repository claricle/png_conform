# frozen_string_literal: true

module PngConform
  module Analyzers
    # Analyzes PNG files for optimization opportunities
    class OptimizationAnalyzer
      # Chunks that are often unnecessary for web/mobile use
      UNNECESSARY_FOR_WEB = %w[tIME pHYs oFFs pCAL sCAL sTER].freeze

      # Text chunk types
      TEXT_CHUNKS = %w[tEXt zTXt iTXt].freeze

      # Metadata chunk types
      METADATA_CHUNKS = %w[tEXt zTXt iTXt tIME pHYs].freeze

      def initialize(result)
        @result = result
        @suggestions = []
      end

      def analyze
        check_unnecessary_chunks
        check_color_depth
        check_palette_opportunity
        check_interlacing
        check_text_chunks
        check_metadata_size

        {
          suggestions: @suggestions,
          potential_savings_bytes: calculate_total_savings,
          potential_savings_percent: calculate_savings_percentage,
        }
      end

      private

      def check_unnecessary_chunks
        unnecessary = @result.chunks.select do |c|
          UNNECESSARY_FOR_WEB.include?(c.type)
        end
        return if unnecessary.empty?

        # Each chunk has: 4 bytes length + 4 bytes type + data + 4 bytes CRC
        savings = unnecessary.sum { |c| c.length + 12 }
        @suggestions << {
          type: :remove_chunks,
          priority: :medium,
          savings_bytes: savings,
          description: "Remove #{unnecessary.count} unnecessary chunks " \
                      "(#{unnecessary.map(&:type).join(', ')})",
          chunks: unnecessary.map(&:type),
        }
      end

      def check_color_depth
        # Get bit depth from IHDR chunk
        ihdr = @result.ihdr_chunk
        return unless ihdr && get_bit_depth(ihdr) == 16

        # Estimate if 8-bit would be sufficient
        if could_use_8_bit?
          current_size = @result.file_size
          estimated_savings = (current_size * 0.45).to_i # ~45% reduction

          @suggestions << {
            type: :reduce_bit_depth,
            priority: :high,
            savings_bytes: estimated_savings,
            description: "Convert from 16-bit to 8-bit depth " \
                        "(estimated ~45% file size reduction)",
            current: "16-bit",
            recommended: "8-bit",
          }
        end
      end

      def check_palette_opportunity
        # Get color type from IHDR
        ihdr = @result.ihdr_chunk
        return unless ihdr && get_color_type(ihdr) == 2 # RGB
        return if @result.file_size < 10_000 # Skip small files

        # If it's RGB but could be palette
        @suggestions << {
          type: :convert_to_palette,
          priority: :medium,
          savings_bytes: (@result.file_size * 0.30).to_i,
          description: "Consider converting to palette mode if using limited colors " \
                      "(potential ~30% reduction)",
          current: "RGB (Truecolor)",
          recommended: "Indexed (Palette)",
        }
      end

      def check_interlacing
        # Get interlace method from IHDR
        ihdr = @result.ihdr_chunk
        return unless ihdr && get_interlace_method(ihdr) == 1

        # Interlaced PNGs are larger
        savings = (@result.file_size * 0.15).to_i

        @suggestions << {
          type: :remove_interlacing,
          priority: :low,
          savings_bytes: savings,
          description: "Remove interlacing for smaller file size " \
                      "(~15% reduction, but slower initial display)",
          current: "Adam7 interlaced",
          recommended: "Non-interlaced",
        }
      end

      def check_text_chunks
        text_chunks = @result.chunks.select { |c| TEXT_CHUNKS.include?(c.type) }
        return if text_chunks.empty?

        total_text_size = text_chunks.sum { |c| c.length + 12 }
        return if total_text_size < 500 # Ignore small metadata

        @suggestions << {
          type: :reduce_metadata,
          priority: :low,
          savings_bytes: total_text_size,
          description: "#{text_chunks.count} text chunks using #{total_text_size} bytes " \
                      "(consider removing non-essential metadata)",
          chunks: text_chunks.map(&:type),
        }
      end

      def check_metadata_size
        metadata_chunks = @result.chunks.select do |c|
          METADATA_CHUNKS.include?(c.type)
        end

        total_metadata = metadata_chunks.sum { |c| c.length + 12 }
        file_size = @result.file_size

        # If metadata is more than 10% of file size
        return unless total_metadata > file_size * 0.1

        @suggestions << {
          type: :excessive_metadata,
          priority: :medium,
          savings_bytes: total_metadata,
          description: "Metadata comprises #{(total_metadata.to_f / file_size * 100).round(1)}% " \
                      "of file size (#{total_metadata} bytes)",
          recommendation: "Review if all metadata is necessary",
        }
      end

      # Helper methods to extract IHDR data
      def get_bit_depth(ihdr_chunk)
        # IHDR data: width(4) + height(4) + bit_depth(1) + ...
        return nil unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 9

        ihdr_chunk.data.bytes[8]
      end

      def get_color_type(ihdr_chunk)
        return nil unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 10

        ihdr_chunk.data.bytes[9]
      end

      def get_interlace_method(ihdr_chunk)
        return nil unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 13

        ihdr_chunk.data.bytes[12]
      end

      def could_use_8_bit?
        # Conservative heuristic: suggest 8-bit for smaller files
        # Without pixel analysis, we're conservative
        @result.file_size < 100_000
      end

      def calculate_total_savings
        @suggestions.sum { |s| s[:savings_bytes] || 0 }
      end

      def calculate_savings_percentage
        return 0 if @result.file_size.zero?

        (calculate_total_savings.to_f / @result.file_size * 100).round(1)
      end
    end
  end
end
