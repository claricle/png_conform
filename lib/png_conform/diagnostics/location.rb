# frozen_string_literal: true

module PngConform
  module Diagnostics
    # PNG-native location: byte offset plus optional chunk type, chunk index
    # and field. Projects onto the shared "binary" location; the field has no
    # shared coordinate, so it travels as the "field" location extension.
    class Location
      attr_reader :byte_offset, :chunk_type, :chunk_index, :field

      def initialize(byte_offset:, chunk_type: nil, chunk_index: nil,
                     field: nil)
        @byte_offset = byte_offset
        @chunk_type = chunk_type
        @chunk_index = chunk_index
        @field = field
        freeze
      end

      def to_lens
        LensCore::Location.binary(
          byte_offset: byte_offset,
          record_index: chunk_index,
          record_type: chunk_type,
          extensions: field.nil? ? {} : { "field" => field },
        )
      end

      def ==(other)
        other.is_a?(self.class) && other.to_a == to_a
      end
      alias eql? ==

      def hash
        to_a.hash
      end

      protected

      def to_a
        [byte_offset, chunk_type, chunk_index, field]
      end
    end
  end
end
