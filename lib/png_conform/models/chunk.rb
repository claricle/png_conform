# frozen_string_literal: true

module PngConform
  module Models
    # Domain model representing a PNG/MNG/JNG chunk
    # This is the business logic representation, separate from binary parsing
    class Chunk < Lutaml::Model::Serializable
      attribute :type, :string
      attribute :length, :integer
      attribute :data, :string
      attribute :crc, :integer
      attribute :offset, :integer
      attribute :valid_crc, :boolean, default: -> { false }
      attribute :crc_expected, :string
      attribute :crc_actual, :string

      # Create from BinData chunk structure
      def self.from_bindata(bindata_chunk, offset = 0)
        new(
          type: bindata_chunk.type,
          length: bindata_chunk.length,
          data: bindata_chunk.data,
          crc: bindata_chunk.crc,
          offset: offset,
          # valid_crc will be set by ValidationService
        )
      end

      # Check if chunk is critical (uppercase first letter)
      def critical?
        type[0] == type[0].upcase
      end

      # Check if chunk is ancillary (lowercase first letter)
      def ancillary?
        !critical?
      end

      # Check if chunk is public (uppercase second letter)
      def public?
        type[1] == type[1].upcase
      end

      # Check if chunk is private (lowercase second letter)
      def private?
        !public?
      end

      # Check if chunk is reserved (uppercase third letter)
      def reserved?
        type[2] == type[2].upcase
      end

      # Check if chunk is safe to copy (lowercase fourth letter)
      def safe_to_copy?
        type[3] == type[3].downcase
      end

      # Get chunk type as symbol
      def type_symbol
        type.to_sym
      end

      # Get total size including all fields
      def total_size
        4 + 4 + length + 4
      end

      # Format offset as hex
      def offset_hex
        format("0x%05x", offset)
      end

      # Alias methods for CRC validation (compatibility with validators and specs)
      def crc_valid?
        valid_crc
      end

      def valid_crc?
        valid_crc
      end
    end
  end
end
