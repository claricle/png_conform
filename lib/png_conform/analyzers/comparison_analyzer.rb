# frozen_string_literal: true

require_relative "../configuration"
require_relative "../services/file_signature"

module PngConform
  module Analyzers
    # Compares two PNG files and reports differences
    class ComparisonAnalyzer
      def initialize(result1, result2, config: Configuration.instance)
        @result1 = result1
        @result2 = result2
        @config = config

        # Fast path: compute signatures for quick equality check
        @sig1 = Services::FileSignature.from_result(result1).compute_signature
        @sig2 = Services::FileSignature.from_result(result2).compute_signature
      end

      def analyze
        # Fast return if signatures are identical
        return identical_result if @sig1 == @sig2

        # Full comparison for different files
        full_comparison
      end

      private

      # Return result for identical files
      #
      # @return [Hash] Analysis result for identical files
      def identical_result
        {
          files: {
            file1: @result1.filename,
            file2: @result2.filename,
            identical: true,
            signature: @sig1.short_signature,
          },
          summary: ["Files are binary identical"],
        }
      end

      # Full comparison for different files
      #
      # @return [Hash] Complete comparison analysis
      def full_comparison
        {
          files: file_comparison,
          image: image_comparison,
          chunks: chunk_comparison,
          validation: validation_comparison,
          quality: quality_comparison,
          summary: generate_summary,
        }
      end

      def file_comparison
        size1 = @result1.file_size
        size2 = @result2.file_size
        diff = size2 - size1
        percent = size1.zero? ? 0 : ((diff.to_f / size1) * 100).round(2)

        {
          file1: @result1.filename,
          file2: @result2.filename,
          size_bytes: {
            file1: size1,
            file2: size2,
            difference: diff,
            change_percent: percent,
          },
          size_change: format_size_change(diff, percent),
        }
      end

      def image_comparison
        ihdr1 = @result1.ihdr_chunk
        ihdr2 = @result2.ihdr_chunk

        w1 = ihdr1 ? get_width(ihdr1) : 0
        h1 = ihdr1 ? get_height(ihdr1) : 0
        w2 = ihdr2 ? get_width(ihdr2) : 0
        h2 = ihdr2 ? get_height(ihdr2) : 0

        {
          dimensions: {
            file1: "#{w1}x#{h1}",
            file2: "#{w2}x#{h2}",
            same: w1 == w2 && h1 == h2,
          },
        }
      end

      def chunk_comparison
        chunks1 = @result1.chunks.map(&:type)
        chunks2 = @result2.chunks.map(&:type)

        {
          count: {
            file1: chunks1.count,
            file2: chunks2.count,
            difference: chunks2.count - chunks1.count,
          },
          added: chunks2 - chunks1,
          removed: chunks1 - chunks2,
          common: chunks1 & chunks2,
          changed: detect_chunk_changes,
        }
      end

      def validation_comparison
        {
          validity: {
            file1: @result1.valid?,
            file2: @result2.valid?,
            same: @result1.valid? == @result2.valid?,
          },
          errors: {
            file1: @result1.error_count,
            file2: @result2.error_count,
            difference: @result2.error_count - @result1.error_count,
          },
          warnings: {
            file1: @result1.warning_count,
            file2: @result2.warning_count,
            difference: @result2.warning_count - @result1.warning_count,
          },
          new_errors: new_errors,
          resolved_errors: resolved_errors,
        }
      end

      def quality_comparison
        {
          compression_ratio: {
            file1: @result1.compression_ratio,
            file2: @result2.compression_ratio,
            improved: compression_improved?,
          },
          has_color_profile: {
            file1: has_color_profile?(@result1),
            file2: has_color_profile?(@result2),
            same: has_color_profile?(@result1) == has_color_profile?(@result2),
          },
          metadata_count: {
            file1: metadata_count(@result1),
            file2: metadata_count(@result2),
            difference: metadata_count(@result2) - metadata_count(@result1),
          },
        }
      end

      def detect_chunk_changes
        common_types = @result1.chunks.map(&:type) & @result2.chunks.map(&:type)
        changed = []

        common_types.each do |type|
          chunk1 = @result1.chunks.find { |c| c.type == type }
          chunk2 = @result2.chunks.find { |c| c.type == type }

          next unless chunk1 && chunk2

          if chunk1.length != chunk2.length || chunk1.crc != chunk2.crc
            changed << {
              type: type,
              size_changed: chunk1.length != chunk2.length,
              data_changed: chunk1.crc != chunk2.crc,
            }
          end
        end

        changed
      end

      def new_errors
        errors1 = @result1.errors.to_set(&:message)
        errors2 = @result2.errors.to_set(&:message)
        (errors2 - errors1).to_a
      end

      def resolved_errors
        errors1 = @result1.errors.to_set(&:message)
        errors2 = @result2.errors.to_set(&:message)
        (errors1 - errors2).to_a
      end

      def compression_improved?
        return false unless @result1.compression_ratio && @result2.compression_ratio

        @result2.compression_ratio > @result1.compression_ratio
      end

      def has_color_profile?(result)
        result.has_chunk?("gAMA") || result.has_chunk?("sRGB") || result.has_chunk?("iCCP")
      end

      def metadata_count(result)
        # Use only text and time chunks from metadata (excluding pHYs which is physical)
        result.chunks.count do |c|
          @config.text_chunks.include?(c.type) || c.type == "tIME"
        end
      end

      def format_size_change(diff, percent)
        if diff.positive?
          "Larger by #{diff} bytes (+#{percent}%)"
        elsif diff.negative?
          "Smaller by #{diff.abs} bytes (#{percent}%)"
        else
          "Same size"
        end
      end

      def generate_summary
        summary = []

        size_diff = @result2.file_size - @result1.file_size
        summary << format_size_summary(size_diff) if size_diff.abs > 1024

        added = chunk_comparison[:added]
        removed = chunk_comparison[:removed]
        summary << "Chunks added: #{added.join(', ')}" if added.any?
        summary << "Chunks removed: #{removed.join(', ')}" if removed.any?

        if @result1.valid? && !@result2.valid?
          summary << "⚠️ File became invalid"
        elsif !@result1.valid? && @result2.valid?
          summary << "✓ File became valid"
        end

        summary
      end

      def format_size_summary(diff)
        diff.positive? ? "File grew by #{format_bytes(diff)}" : "File reduced by #{format_bytes(diff.abs)} ✓"
      end

      def format_bytes(bytes)
        if bytes < 1024
          "#{bytes} bytes"
        elsif bytes < 1024 * 1024
          "#{(bytes / 1024.0).round(2)} KB"
        else
          "#{(bytes / 1024.0 / 1024.0).round(2)} MB"
        end
      end

      # Helper methods to extract IHDR data
      def get_width(ihdr_chunk)
        return 0 unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 4

        ihdr_chunk.data.bytes[0..3].pack("C*").unpack1("N")
      end

      def get_height(ihdr_chunk)
        return 0 unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 8

        ihdr_chunk.data.bytes[4..7].pack("C*").unpack1("N")
      end
    end
  end
end
