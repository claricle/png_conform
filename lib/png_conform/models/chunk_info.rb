# frozen_string_literal: true

require "lutaml/model"

module PngConform
  module Models
    # Domain model representing PNG chunk metadata
    class ChunkInfo < Lutaml::Model::Serializable
      attribute :type, :string
      attribute :offset, :integer
      attribute :length, :integer
      attribute :crc_valid, :boolean
      attribute :critical, :boolean
      attribute :private, :boolean
      attribute :safe_to_copy, :boolean
      attribute :decoded_data, DecodedChunkData

      # Binary data - use attr_accessor to avoid Lutaml serialization corruption
      attr_accessor :data, :crc

      # Custom initializer to handle binary data fields
      def initialize(attributes = {})
        @data = attributes.delete(:data)
        @crc = attributes.delete(:crc)
        super(attributes)
      end

      # Format offset as hex for display
      def offset_hex
        format("0x%05x", offset)
      end

      # Chunk property summary
      def properties
        props = []
        props << "critical" if critical
        props << "ancillary" unless critical
        props << "private" if private
        props << "safe-to-copy" if safe_to_copy
        props
      end

      # Format chunk for verbose output
      # Example: "chunk IHDR at offset 0x0000c, length 13"
      def summary
        "chunk #{type} at offset #{offset_hex}, length #{length}"
      end

      # Format with decoded data
      def detailed_summary
        parts = [summary]
        parts << decoded_data.summary if decoded_data
        parts.join("\n    ")
      end

      # Aliases for compatibility with spec expectations
      alias chunk_type type
      alias abs_offset offset

      # Force binary encoding for chunk data
      def chunk_data
        data&.b
      end

      # CRC validation method alias
      def crc_valid?
        crc_valid
      end
    end
  end
end
