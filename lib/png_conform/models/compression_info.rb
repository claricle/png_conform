# frozen_string_literal: true

require "lutaml/model"

module PngConform
  module Models
    # Domain model representing PNG compression metadata
    class CompressionInfo < Lutaml::Model::Serializable
      attribute :uncompressed_size, :integer
      attribute :compressed_size, :integer
      attribute :compression_ratio, :float
      attribute :window_bits, :integer
      attribute :compression_level, :string

      # Compression level constants
      COMPRESSION_LEVELS = {
        1 => "fastest",
        6 => "default",
        9 => "maximum",
      }.freeze

      # Calculate compression ratio from sizes
      def self.calculate_ratio(uncompressed, compressed)
        return 0.0 if uncompressed.zero?

        ((compressed.to_f / uncompressed) - 1.0) * 100.0
      end

      # Get compression level name
      def level_name
        COMPRESSION_LEVELS[compression_level] || "custom"
      end

      # Format compression info for display
      def summary
        format("%.1f%%", compression_ratio)
      end

      # Format full details (for verbose mode)
      def details
        parts = []
        parts << "deflated"
        parts << "#{window_bits}K window" if window_bits
        parts << "#{level_name} compression"
        parts.join(", ")
      end
    end
  end
end
