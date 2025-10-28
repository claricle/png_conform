# frozen_string_literal: true

require_relative "base_reporter"
require "json"

module PngConform
  module Reporters
    # JSON reporter - outputs comprehensive validation results in JSON format
    # Includes file info, image details, chunks, errors, and analysis
    class JsonReporter < BaseReporter
      # rubocop:disable Metrics/MethodLength
      def report(validation_result)
        # Build comprehensive hash with all data
        data = {
          "filename" => validation_result.filename,
          "file_type" => validation_result.file_type,
          "file_size" => validation_result.file_size,
          "compression_ratio" => validation_result.compression_ratio,
          "crc_errors_count" => validation_result.crc_errors_count,
          "valid" => validation_result.valid?,
        }

        # Add image information from IHDR
        if validation_result.ihdr_chunk
          ihdr = validation_result.ihdr_chunk
          data["image"] = {
            "width" => get_width(ihdr),
            "height" => get_height(ihdr),
            "bit_depth" => get_bit_depth(ihdr),
            "color_type" => get_color_type(ihdr),
            "color_type_name" => color_type_name(get_color_type(ihdr)),
            "interlaced" => get_interlace_method(ihdr) == 1,
          }
        end

        # Add chunk summary
        data["chunks"] = {
          "total" => validation_result.chunks.count,
          "types" => validation_result.chunks.map(&:type).uniq.sort,
        }

        # Add errors if present
        if validation_result.errors.any?
          data["errors"] = validation_result.errors.map do |error|
            error_hash = {
              "severity" => error.severity,
              "message" => error.message,
            }
            error_hash["chunk_type"] = error.chunk_type if error.chunk_type
            error_hash["expected"] = error.expected if error.expected
            error_hash["actual"] = error.actual if error.actual
            error_hash
          end
        end

        # Add resolution analysis
        if validation_result.ihdr_chunk
          resolution_analyzer = Analyzers::ResolutionAnalyzer.new(validation_result)
          resolution_data = resolution_analyzer.analyze

          data["resolution"] = {
            "dimensions" => resolution_data[:resolution][:dimensions],
            "megapixels" => resolution_data[:resolution][:megapixels],
            "dpi" => resolution_data[:resolution][:dpi],
            "retina" => {
              "at_1x" => resolution_data[:retina][:at_1x][:dimensions_pt],
              "at_2x" => resolution_data[:retina][:at_2x][:dimensions_pt],
              "at_3x" => resolution_data[:retina][:at_3x][:dimensions_pt],
              "recommended" => resolution_data[:retina][:recommended_density],
              "ios" => resolution_data[:retina][:ios_asset_catalog],
              "android" => resolution_data[:retina][:android_density],
            },
          }

          # Add recommendations if any
          recommendations = resolution_data[:recommendations]
          if recommendations && !recommendations.empty?
            data["recommendations"] = recommendations.map { |r| r[:message] }
          end
        end

        # Add optimization suggestions
        optimization_analyzer = Analyzers::OptimizationAnalyzer.new(validation_result)
        optimization_data = optimization_analyzer.analyze

        if optimization_data[:suggestions].any?
          data["optimization"] = {
            "suggestions" => optimization_data[:suggestions].map do |s|
              {
                "priority" => s[:priority].to_s,
                "description" => s[:description],
                "savings_bytes" => s[:savings_bytes],
              }
            end,
            "total_savings_bytes" => optimization_data[:potential_savings_bytes],
            "total_savings_percent" => optimization_data[:potential_savings_percent],
          }
        end

        write_line(JSON.pretty_generate(data))
      end
      # rubocop:enable Metrics/MethodLength

      private

      # Helper methods to extract IHDR data
      def get_width(ihdr_chunk)
        return 0 unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 4

        ihdr_chunk.data.bytes[0..3].pack("C*").unpack1("N")
      end

      def get_height(ihdr_chunk)
        return 0 unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 8

        ihdr_chunk.data.bytes[4..7].pack("C*").unpack1("N")
      end

      def get_bit_depth(ihdr_chunk)
        return 0 unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 9

        ihdr_chunk.data.bytes[8]
      end

      def get_color_type(ihdr_chunk)
        return 0 unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 10

        ihdr_chunk.data.bytes[9]
      end

      def get_interlace_method(ihdr_chunk)
        return 0 unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 13

        ihdr_chunk.data.bytes[12]
      end

      def color_type_name(color_type)
        case color_type
        when 0 then "Grayscale"
        when 2 then "RGB"
        when 3 then "Indexed"
        when 4 then "Grayscale+Alpha"
        when 6 then "RGBA"
        else "Unknown"
        end
      end
    end
  end
end
