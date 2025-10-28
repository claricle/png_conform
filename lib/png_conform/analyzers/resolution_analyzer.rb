# frozen_string_literal: true

module PngConform
  module Analyzers
    # Analyzes PNG resolution and DPI for various use cases
    class ResolutionAnalyzer
      # Standard DPI values
      SCREEN_DPI = 72
      PRINT_DPI_LOW = 150
      PRINT_DPI_STANDARD = 300
      PRINT_DPI_HIGH = 600

      # Retina display densities
      RETINA_1X = 1.0
      RETINA_2X = 2.0
      RETINA_3X = 3.0

      def initialize(result)
        @result = result
        ihdr = result.ihdr_chunk
        @width = ihdr ? get_width(ihdr) : 0
        @height = ihdr ? get_height(ihdr) : 0
        @dpi = extract_dpi
      end

      def analyze
        {
          resolution: resolution_info,
          retina: retina_analysis,
          print: print_analysis,
          web: web_analysis,
          recommendations: generate_recommendations,
        }
      end

      private

      # Extract data from IHDR chunk
      def get_width(ihdr_chunk)
        return 0 unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 4

        ihdr_chunk.data.bytes[0..3].pack("C*").unpack1("N")
      end

      def get_height(ihdr_chunk)
        return 0 unless ihdr_chunk.data && ihdr_chunk.data.bytesize >= 8

        ihdr_chunk.data.bytes[4..7].pack("C*").unpack1("N")
      end

      def resolution_info
        {
          width_px: @width,
          height_px: @height,
          dimensions: "#{@width}x#{@height}",
          total_pixels: @width * @height,
          megapixels: (@width * @height / 1_000_000.0).round(2),
          dpi: @dpi,
          has_dpi_metadata: !@dpi.nil?,
        }
      end

      def retina_analysis
        analysis = {
          is_retina_ready: check_retina_ready,
          at_1x: calculate_physical_size(RETINA_1X),
          at_2x: calculate_physical_size(RETINA_2X),
          at_3x: calculate_physical_size(RETINA_3X),
        }

        analysis[:recommended_density] = recommend_density
        analysis[:ios_asset_catalog] = ios_asset_suggestions
        analysis[:android_density] = android_density_bucket

        analysis
      end

      def print_analysis
        return { capable: false, reason: "No DPI metadata" } unless @dpi

        width_inches = @width.to_f / @dpi
        height_inches = @height.to_f / @dpi

        {
          capable: @dpi >= PRINT_DPI_LOW,
          dpi: @dpi,
          physical_size: {
            width_inches: width_inches.round(2),
            height_inches: height_inches.round(2),
            width_cm: (width_inches * 2.54).round(2),
            height_cm: (height_inches * 2.54).round(2),
          },
          quality: print_quality_assessment,
          suitable_for: suitable_print_sizes,
        }
      end

      def web_analysis
        {
          suitable_for_web: @width <= 4096 && @height <= 4096,
          typical_screen_size: calculate_screen_coverage,
          mobile_friendly: @width <= 1920 && @height <= 1920,
          retina_optimized: @width >= 1000 && @height >= 1000,
          load_time_estimate: estimate_load_time,
        }
      end

      def extract_dpi
        # Look for pHYs chunk
        phys_chunk = @result.chunks_by_type("pHYs").first
        return nil unless phys_chunk&.data && phys_chunk.data.bytesize >= 9

        # pHYs: pixels_per_unit_x(4) + pixels_per_unit_y(4) + unit_specifier(1)
        unit = phys_chunk.data.bytes[8]
        return nil unless unit == 1 # 1 = meters

        pixels_per_meter = phys_chunk.data.bytes[0..3].pack("C*").unpack1("N")
        (pixels_per_meter * 0.0254).round # Convert to DPI
      end

      def check_retina_ready
        @width >= 88 && @height >= 88
      end

      def calculate_physical_size(density)
        css_reference_dpi = 163
        effective_dpi = css_reference_dpi * density

        width_points = (@width.to_f / effective_dpi * 72).round(1)
        height_points = (@height.to_f / effective_dpi * 72).round(1)

        {
          width_points: width_points,
          height_points: height_points,
          dimensions_pt: "#{width_points}x#{height_points}pt",
          suitable_for: suitable_element_sizes(width_points, height_points),
        }
      end

      def recommend_density
        pixels = @width * @height
        case pixels
        when 0..10_000 then "@1x (too small for higher densities)"
        when 10_001..100_000 then "@1x or @2x"
        when 100_001..500_000 then "@2x"
        when 500_001..2_000_000 then "@2x or @3x"
        else "@3x"
        end
      end

      def ios_asset_suggestions
        suggestions = []

        if @width == @height
          case @width
          when 20 then suggestions << "Icon 20pt @1x (Settings)"
          when 40 then suggestions << "Icon 20pt @2x (Settings)"
          when 60 then suggestions << "Icon 20pt @3x or 60pt @1x"
          when 29 then suggestions << "Icon 29pt @1x"
          when 58 then suggestions << "Icon 29pt @2x"
          when 87 then suggestions << "Icon 29pt @3x"
          when 1024 then suggestions << "App Store Icon (1024x1024)"
          end
        end

        suggestions.empty? ? ["Custom size"] : suggestions
      end

      def android_density_bucket
        case @width
        when 0..120 then "ldpi or mdpi"
        when 121..240 then "mdpi or hdpi"
        when 241..480 then "hdpi or xhdpi"
        when 481..720 then "xhdpi or xxhdpi"
        when 721..960 then "xxhdpi or xxxhdpi"
        else "xxxhdpi or custom"
        end
      end

      def print_quality_assessment
        return "Unknown" unless @dpi

        case @dpi
        when 0...PRINT_DPI_LOW then "Not suitable"
        when PRINT_DPI_LOW...PRINT_DPI_STANDARD then "Acceptable"
        when PRINT_DPI_STANDARD...PRINT_DPI_HIGH then "Good"
        else "Excellent"
        end
      end

      def suitable_print_sizes
        return [] unless @dpi && @dpi >= PRINT_DPI_LOW

        width_in = @width.to_f / @dpi
        height_in = @height.to_f / @dpi

        sizes = []
        sizes << "4x6\"" if width_in >= 4 && height_in >= 6
        sizes << "5x7\"" if width_in >= 5 && height_in >= 7
        sizes << "8x10\"" if width_in >= 8 && height_in >= 10

        sizes.empty? ? ["Small prints only"] : sizes
      end

      def calculate_screen_coverage
        screens = {
          "Mobile (375x667)" => { w: 375, h: 667 },
          "Desktop (1920x1080)" => { w: 1920, h: 1080 },
        }

        screens.transform_values do |screen|
          w_pct = (@width.to_f / screen[:w] * 100).round(1)
          h_pct = (@height.to_f / screen[:h] * 100).round(1)
          "#{w_pct}% x #{h_pct}%"
        end
      end

      def suitable_element_sizes(width_pt, height_pt)
        elements = []
        elements << "Small icon" if width_pt < 32 && height_pt < 32
        elements << "Standard icon" if width_pt.between?(32, 64)
        elements << "Large icon" if width_pt.between?(64, 128)
        elements << "Banner" if width_pt > 300

        elements.empty? ? ["Custom"] : elements
      end

      def estimate_load_time
        file_size = @result.file_size
        mbps = 5
        bytes_per_second = (mbps * 1_000_000 / 8).to_i
        seconds = file_size.to_f / bytes_per_second

        if seconds < 0.1
          "< 0.1s"
        elsif seconds < 1
          "#{(seconds * 1000).round}ms"
        else
          "#{seconds.round(1)}s"
        end
      end

      def generate_recommendations
        recs = []

        if @width < 100 && @height < 100
          recs << {
            category: :retina,
            priority: :high,
            message: "Image is too small for Retina displays - consider @2x/@3x versions",
          }
        end

        unless @dpi
          recs << {
            category: :metadata,
            priority: :medium,
            message: "Add pHYs chunk with DPI information for print compatibility",
          }
        end

        if @width > 3000 || @height > 3000
          recs << {
            category: :web,
            priority: :high,
            message: "Image is very large for web - consider reducing dimensions",
          }
        end

        recs
      end
    end
  end
end
