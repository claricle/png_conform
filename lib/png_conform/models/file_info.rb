# frozen_string_literal: true

module PngConform
  module Models
    # Domain model representing file metadata
    class FileInfo < Lutaml::Model::Serializable
      attribute :filename, :string
      attribute :file_size, :integer
      attribute :file_type, :string
      attribute :signature, :string
      attribute :width, :integer
      attribute :height, :integer
      attribute :bit_depth, :integer
      attribute :color_type, :integer
      attribute :compression_method, :integer
      attribute :filter_method, :integer
      attribute :interlace_method, :integer

      # File types
      FILE_TYPE_PNG = "PNG"
      FILE_TYPE_MNG = "MNG"
      FILE_TYPE_JNG = "JNG"
      FILE_TYPE_UNKNOWN = "UNKNOWN"

      # Color type constants (PNG)
      COLOR_TYPE_GRAYSCALE = 0
      COLOR_TYPE_RGB = 2
      COLOR_TYPE_INDEXED = 3
      COLOR_TYPE_GRAYSCALE_ALPHA = 4
      COLOR_TYPE_RGB_ALPHA = 6

      # Color type names
      COLOR_TYPE_NAMES = {
        COLOR_TYPE_GRAYSCALE => "grayscale",
        COLOR_TYPE_RGB => "RGB",
        COLOR_TYPE_INDEXED => "indexed",
        COLOR_TYPE_GRAYSCALE_ALPHA => "grayscale+alpha",
        COLOR_TYPE_RGB_ALPHA => "RGB+alpha",
      }.freeze

      # Get color type name
      def color_type_name
        COLOR_TYPE_NAMES[color_type] || "unknown"
      end

      # Get interlace method name
      def interlace_method_name
        case interlace_method
        when 0 then "non-interlaced"
        when 1 then "Adam7 interlaced"
        else "unknown"
        end
      end

      # Check if image is interlaced
      def interlaced?
        interlace_method == 1
      end

      # Get image dimensions as string
      def dimensions
        "#{width}x#{height}"
      end

      # Get bit depth description
      def bit_depth_description
        "#{bit_depth}-bit #{color_type_name}"
      end

      # Format signature as hex
      def signature_hex
        signature&.unpack1("H*")
      end

      # Check if file is PNG
      def png?
        file_type == FILE_TYPE_PNG
      end

      # Check if file is MNG
      def mng?
        file_type == FILE_TYPE_MNG
      end

      # Check if file is JNG
      def jng?
        file_type == FILE_TYPE_JNG
      end
    end
  end
end
