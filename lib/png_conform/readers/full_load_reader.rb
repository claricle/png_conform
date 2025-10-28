# frozen_string_literal: true

require_relative "../bindata/png_file"

module PngConform
  module Readers
    # Full-file PNG reader
    #
    # This reader loads the entire PNG file into memory at once, providing
    # fast random access to chunks but using more memory. Suitable for
    # small to medium files or when you need to access chunks non-sequentially.
    #
    # @example Reading an entire PNG file
    #   File.open("image.png", "rb") do |f|
    #     reader = FullLoadReader.new(f)
    #     png = reader.read
    #
    #     puts "Signature valid: #{png.valid_signature?}"
    #     puts "Chunks: #{png.chunk_sequence.join(', ')}"
    #     puts "Structurally valid: #{png.structurally_valid?}"
    #   end
    #
    class FullLoadReader
      attr_reader :io, :png

      # Initialize a new full-load reader
      #
      # @param filepath_or_io [String, IO] File path or IO object to read from
      def initialize(filepath_or_io)
        if filepath_or_io.is_a?(String)
          # File path provided
          @filepath = filepath_or_io
          @io = File.open(filepath_or_io, "rb")
          @owns_io = true
        else
          # IO object provided
          @io = filepath_or_io
          @owns_io = false
        end
        @png = nil
      end

      # Read the entire PNG file structure
      #
      # @return [BinData::PngFile] the complete PNG file structure
      def read
        return @png if @png

        @io.rewind
        @png = BinData::PngFile.read(@io)
      end

      # Get PNG signature
      #
      # @return [String] 8-byte PNG signature
      def signature
        read unless @png
        @png.signature.to_s
      end

      # Iterate over each chunk
      #
      # @yield [chunk] Each chunk in the file
      def each_chunk(&block)
        read unless @png
        @png.chunks.each(&block)
      end

      # Get file size
      #
      # @return [Integer] File size in bytes
      def file_size
        if @filepath
          File.size(@filepath)
        elsif @io.respond_to?(:stat)
          @io.stat.size
        else
          # Fallback: calculate from PNG structure
          read unless @png
          8 + @png.chunks.sum { |c| 12 + c.length }
        end
      end

      # Close the IO if we own it
      def close
        @io.close if @owns_io && @io && !@io.closed?
      end

      # Read file from path and return PNG structure
      #
      # @param path [String] path to PNG file
      # @return [BinData::PngFile] the PNG file structure
      def self.read_file(path)
        File.open(path, "rb") do |f|
          new(f).read
        end
      end

      # Read file from path and yield PNG structure to block
      #
      # @param path [String] path to PNG file
      # @yield [png] The PNG file structure
      # @yieldparam png [BinData::PngFile] the PNG structure
      # @return [Object] result of the block
      def self.open(path)
        File.open(path, "rb") do |f|
          png = new(f).read
          yield png
        end
      end
    end
  end
end
