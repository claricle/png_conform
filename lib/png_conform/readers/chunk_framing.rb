# frozen_string_literal: true

module PngConform
  module Readers
    # Bounds a chunk's declared length before any reader allocates for it.
    #
    # A corrupted length field (for example a CR-LF converted to LF shifting
    # the framing) can declare gigabytes of data. Handing that to BinData
    # makes the failure depend on the host (Errno::EINVAL on macOS, other
    # errors or a huge allocation elsewhere). The check works on the 4-byte
    # length and the file size alone, so it never allocates for the chunk.
    module ChunkFraming
      # ISO/IEC 15948 section 5.3: a chunk length is 0 to 2^31-1.
      MAX_LENGTH = (2**31) - 1
      HEADER_BYTES = 8
      CRC_BYTES = 4

      # A chunk whose declared extent is not valid.
      #
      # rule is :exceeds_limit (length above MAX_LENGTH) or :exceeds_data
      # (data and CRC do not fit in the bytes that follow the chunk header).
      Violation = Struct.new(:rule, :offset, :chunk_index, :declared_length,
                             :available, keyword_init: true)

      module_function

      # @param io [IO] positioned at a chunk's length field
      # @return [Integer, nil] declared length, or nil when fewer than eight
      #   bytes remain or the IO cannot seek; the position is unchanged
      def peek_length(io)
        return nil unless io.respond_to?(:seek)

        pos = io.pos
        header = io.read(HEADER_BYTES)
        io.seek(pos)
        return nil if header.nil? || header.bytesize < HEADER_BYTES

        header.unpack1("N")
      end

      # @param io [IO]
      # @return [Integer, nil] total byte size, nil when unknown
      def size_of(io)
        return io.size if io.respond_to?(:size)

        io.stat.size if io.respond_to?(:stat)
      end

      # @param length [Integer] declared chunk data length
      # @param offset [Integer] absolute offset of the length field
      # @param chunk_index [Integer] zero-based index of the chunk
      # @param total [Integer, nil] file size in bytes
      # @return [Violation, nil]
      def violation(length, offset:, chunk_index:, total:)
        available = total && (total - offset - HEADER_BYTES)
        rule = if length > MAX_LENGTH
                 :exceeds_limit
               elsif available && length + CRC_BYTES > available
                 :exceeds_data
               end
        return unless rule

        Violation.new(rule: rule, offset: offset, chunk_index: chunk_index,
                      declared_length: length, available: available)
      end

      # Check the chunk whose length field is at the IO's position.
      #
      # @return [Violation, nil]
      def check(io, chunk_index)
        length = peek_length(io)
        return unless length

        violation(length, offset: io.pos, chunk_index: chunk_index,
                          total: size_of(io))
      end
    end
  end
end
