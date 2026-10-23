# frozen_string_literal: true

module PngConform
  module Readers
    # Single signature-to-format dispatch table for PNG, MNG and JNG.
    #
    # Each format names the chunk types its top-level sequence rules need:
    # the header that must come first, the terminator that must come last,
    # and the image-data chunk that must appear at least once (MNG has none).
    module FormatDispatch
      Format = Struct.new(:key, :name, :signature, :header, :terminator,
                          :data_chunk, keyword_init: true)

      PNG = Format.new(
        key: :png, name: "PNG",
        signature: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
          .pack("C*").freeze,
        header: "IHDR", terminator: "IEND", data_chunk: "IDAT"
      ).freeze

      MNG = Format.new(
        key: :mng, name: "MNG",
        signature: [0x8A, 0x4D, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
          .pack("C*").freeze,
        header: "MHDR", terminator: "MEND", data_chunk: nil
      ).freeze

      JNG = Format.new(
        key: :jng, name: "JNG",
        signature: [0x8B, 0x4A, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
          .pack("C*").freeze,
        header: "JHDR", terminator: "IEND", data_chunk: "JDAT"
      ).freeze

      FORMATS = [PNG, MNG, JNG].freeze
      BY_SIGNATURE = FORMATS.to_h { |f| [f.signature, f] }.freeze

      module_function

      # @param signature [String, nil] the first eight bytes of a file
      # @return [Format, nil] the matching format, or nil when unrecognized
      def detect(signature)
        return nil if signature.nil?

        BY_SIGNATURE[signature.b]
      end
    end
  end
end
