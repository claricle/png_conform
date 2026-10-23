# frozen_string_literal: true

require "zlib"
require "tempfile"

module PngConform
  module Spec
    # Builds minimal, complete PNG / MNG / JNG files with valid CRCs.
    module FormatFileBuilder
      PNG_SIG = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack("C*").freeze
      MNG_SIG = [0x8A, 0x4D, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack("C*").freeze
      JNG_SIG = [0x8B, 0x4A, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack("C*").freeze
      UNKNOWN_SIG = "GIF89a\x00\x00".b.freeze

      module_function

      def chunk(type, data = "")
        data = data.b
        [data.bytesize].pack("N") + type.b + data +
          [Zlib.crc32(type.b + data)].pack("N")
      end

      def ihdr = chunk("IHDR", [1, 1, 8, 0, 0, 0, 0].pack("NNC5"))
      def idat = chunk("IDAT", Zlib::Deflate.deflate("\x00\x80".b))
      def iend = chunk("IEND")
      def mhdr = chunk("MHDR", [1, 1, 1, 1, 1, 1, 0].pack("N7"))
      def mend = chunk("MEND")
      def jhdr = chunk("JHDR", [1, 1].pack("NN") + [10, 8, 8, 0, 0, 0, 0, 0].pack("C8"))
      def jdat = chunk("JDAT", "\xFF\xD8\xFF\xD9".b)

      def png(*chunks) = PNG_SIG + chunks.join
      def mng(*chunks) = MNG_SIG + chunks.join
      def jng(*chunks) = JNG_SIG + chunks.join

      def valid_png = png(ihdr, idat, iend)
      def valid_mng = mng(mhdr, mend)
      def valid_jng = jng(jhdr, jdat, iend)

      # Write bytes to a temporary file and yield its path.
      def with_file(bytes, ext)
        Tempfile.create(["format-aware", ext], binmode: true) do |file|
          file.write(bytes)
          file.flush
          yield file.path
        end
      end
    end
  end
end
