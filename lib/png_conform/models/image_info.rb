# frozen_string_literal: true

require "lutaml/model"

module PngConform
  module Models
    # Domain model representing PNG image metadata
    class ImageInfo < Lutaml::Model::Serializable
      attribute :width, :integer
      attribute :height, :integer
      attribute :bit_depth, :integer
      attribute :color_type, :string
      attribute :interlaced, :boolean
      attribute :animated, :boolean

      # Color type constants for validation
      COLOR_TYPES = {
        0 => "grayscale",
        2 => "truecolor",
        3 => "palette",
        4 => "grayscale+alpha",
        6 => "truecolor+alpha",
      }.freeze

      # Convert color type code to human-readable string
      def self.color_type_name(code)
        COLOR_TYPES[code] || "unknown"
      end

      # Format as pngcheck summary (e.g., "32x32, 1-bit grayscale")
      def summary
        parts = []
        parts << "#{width}x#{height}"
        parts << "#{bit_depth}-bit #{color_type}"
        parts << (interlaced ? "interlaced" : "non-interlaced")
        parts << (animated ? "animated" : "static")
        parts.join(", ")
      end
    end
  end
end
