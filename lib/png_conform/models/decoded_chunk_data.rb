# frozen_string_literal: true

require "lutaml/model"

module PngConform
  module Models
    # Base class for decoded chunk data
    class DecodedChunkData < Lutaml::Model::Serializable
      # Override in subclasses to provide formatted summary
      def summary
        ""
      end
    end

    # IHDR chunk decoded data
    class IhdrData < DecodedChunkData
      attribute :width, :integer
      attribute :height, :integer
      attribute :bit_depth, :integer
      attribute :color_type, :integer
      attribute :compression_method, :integer
      attribute :filter_method, :integer
      attribute :interlace_method, :integer

      COLOR_TYPE_NAMES = {
        0 => "grayscale",
        2 => "truecolor",
        3 => "palette",
        4 => "grayscale+alpha",
        6 => "truecolor+alpha",
      }.freeze

      def color_type_name
        COLOR_TYPE_NAMES[color_type] || "unknown"
      end

      def interlaced?
        interlace_method == 1
      end

      def summary
        parts = []
        parts << "#{width} x #{height} image"
        parts << "#{bit_depth}-bit #{color_type_name}"
        parts << (interlaced? ? "interlaced" : "non-interlaced")
        parts.join(", ")
      end
    end

    # gAMA chunk decoded data
    class GamaData < DecodedChunkData
      attribute :gamma, :float

      def summary
        format("%.4f", gamma)
      end
    end

    # IDAT chunk decoded data
    class IdatData < DecodedChunkData
      attribute :compression_method, :integer
      attribute :window_bits, :integer
      attribute :compression_level, :string
      attribute :row_filters, :integer, collection: true

      def summary
        parts = []
        parts << "zlib: deflated"
        parts << "#{window_bits}K window" if window_bits
        parts << "#{compression_level} compression" if compression_level
        parts.join(", ")
      end

      # Format row filters for very verbose mode
      def filter_summary
        return nil if row_filters.nil? || row_filters.empty?

        filter_names = {
          0 => "none",
          1 => "sub",
          2 => "up",
          3 => "avg",
          4 => "paeth",
        }
        "row filters (#{filter_names.map do |k, v|
          "#{k} #{v}"
        end.join(', ')}):\n      #{row_filters.join(' ')}"
      end
    end

    # Palette entry
    class PaletteEntry < Lutaml::Model::Serializable
      attribute :red, :integer
      attribute :green, :integer
      attribute :blue, :integer
    end

    # PLTE chunk decoded data
    class PlteData < DecodedChunkData
      attribute :entries, PaletteEntry, collection: true

      def summary
        "#{entries&.size || 0} palette entries"
      end

      # Format for palette printing mode
      def detailed_entries
        return [] unless entries

        entries.each_with_index.map do |entry, index|
          format("%3d:  (%3d,%3d,%3d) = (0x%02x,0x%02x,0x%02x)",
                 index, entry.red, entry.green, entry.blue,
                 entry.red, entry.green, entry.blue)
        end
      end
    end

    # tEXt chunk decoded data
    class TextData < DecodedChunkData
      attribute :keyword, :string
      attribute :text, :string

      def summary
        "#{keyword}: #{text}"
      end
    end

    # tIME chunk decoded data
    class TimeData < DecodedChunkData
      attribute :year, :integer
      attribute :month, :integer
      attribute :day, :integer
      attribute :hour, :integer
      attribute :minute, :integer
      attribute :second, :integer

      def summary
        format("%04d-%02d-%02d %02d:%02d:%02d",
               year, month, day, hour, minute, second)
      end
    end

    # iDOT chunk decoded data
    class IdotData < DecodedChunkData
      attribute :display_scale, :integer
      attribute :pixel_format, :integer
      attribute :color_space, :integer
      attribute :backing_scale_factor, :integer
      attribute :flags, :integer
      attribute :reserved1, :integer
      attribute :reserved2, :integer

      def summary
        parts = []
        parts << "display scale: #{display_scale}" if display_scale
        parts << "pixel format: #{pixel_format}" if pixel_format
        parts << "color space: #{color_space}" if color_space
        parts << "backing scale: #{backing_scale_factor}" if backing_scale_factor
        parts.join(", ")
      end

      # Format all seven values for detailed display
      def detailed_info
        [
          display_scale,
          pixel_format,
          color_space,
          backing_scale_factor,
          flags,
          reserved1,
          reserved2,
        ].join(", ")
      end
    end
  end
end
