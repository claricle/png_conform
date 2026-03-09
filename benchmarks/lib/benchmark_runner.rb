# frozen_string_literal: true

require_relative "png_conform_runner"
require_relative "pngcheck_runner"
require_relative "metrics_collector"
require_relative "report_generator"
require "yaml"

# Main orchestrator for benchmark execution.
#
# Coordinates file discovery, tool execution, metrics collection,
# and report generation for comparing PNG validation tools.
class BenchmarkRunner
  attr_reader :config, :metrics_collector, :runners

  def initialize(config = {})
    @config = deep_merge(default_config, config)
    @metrics_collector = MetricsCollector.new
    @runners = initialize_runners
  end

  # Run the complete benchmark suite.
  #
  # @return [Hash] Benchmark results
  def run
    puts "Initializing benchmark..."
    validate_tools

    files = discover_files
    puts "Found #{files.size} PNG files to test"

    return { error: "No files found matching pattern" } if files.empty?

    puts "\nRunning benchmarks..."
    puts "  Iterations: #{config[:iterations]}"
    puts "  Warmup runs: #{config[:warmup_runs]}"
    puts ""

    run_benchmarks(files)

    puts "\nGenerating report..."
    generate_report
  end

  private

  def default_config
    {
      test_files: {
        pattern: "spec/fixtures/pngsuite/**/*.png",
        exclude: [],
        limit: nil,
      },
      iterations: 3,
      warmup_runs: 1,
      timeout: 30,
      tools: {
        png_conform: { enabled: true, options: {} },
        pngcheck: { enabled: true, options: {} },
      },
      output: {
        format: "text",
        file: nil,
        verbose: true,
      },
    }
  end

  def initialize_runners
    runners = {}

    if config[:tools][:png_conform][:enabled]
      runners[:png_conform] = PngConformRunner.new(
        config[:tools][:png_conform][:options],
      )
    end

    if config[:tools][:pngcheck][:enabled]
      runners[:pngcheck] = PngcheckRunner.new(
        config[:tools][:pngcheck][:options],
      )
    end

    runners
  end

  def validate_tools
    puts "Checking tool availability..."

    runners.each do |name, runner|
      if runner.available?
        puts "  ✓ #{name} is available"
      else
        puts "  ✗ #{name} is NOT available"
        if name == :pngcheck
          puts "    Install with: brew install pngcheck (macOS) or apt-get install pngcheck (Linux)"
        end
      end
    end

    puts ""
  end

  def discover_files
    pattern = config.dig(:test_files, :pattern)
    exclude = config.dig(:test_files, :exclude) || []
    limit = config.dig(:test_files, :limit)

    files = Dir.glob(pattern).select { |f| File.file?(f) }

    # Apply exclusions
    exclude.each do |pattern|
      files.reject! { |f| File.fnmatch?(pattern, f) }
    end

    # Apply limit if specified
    files = files.first(limit) if limit

    files.sort
  end

  def run_benchmarks(files)
    total_iterations = config[:iterations] + config[:warmup_runs]
    total_runs = files.size * runners.size * total_iterations
    current_run = 0

    runners.each do |tool_name, runner|
      next unless runner.available?

      puts "Benchmarking #{tool_name}..."

      files.each do |file|
        # Warmup runs (not recorded)
        config[:warmup_runs].times do
          current_run += 1
          if config[:output][:verbose]
            print_progress("Warmup", current_run,
                           total_runs)
          end
          runner.run(file)
        end

        # Actual benchmark runs (recorded)
        config[:iterations].times do |_iteration|
          current_run += 1
          if config[:output][:verbose]
            print_progress(tool_name, current_run,
                           total_runs)
          end

          metrics = runner.run(file)
          metrics_collector.record_run(
            tool_name.to_s,
            file,
            metrics,
          )
        end
      end

      puts "" if config[:output][:verbose]
    end
  end

  def print_progress(label, current, total)
    pct = (current.to_f / total * 100).round(1)
    bar_width = 40
    filled = (bar_width * current / total).to_i
    bar = ("=" * filled) + (" " * (bar_width - filled))

    print "\r  [#{bar}] #{pct}% (#{current}/#{total}) #{label}     "
    $stdout.flush
  end

  def generate_report
    report_gen = ReportGenerator.new(metrics_collector, config[:output])
    report = report_gen.generate(config[:output][:format])

    if config[:output][:file]
      File.write(config[:output][:file], report)
      puts "Report saved to: #{config[:output][:file]}"
    else
      puts "\n"
      puts report
    end

    {
      summary: metrics_collector.summary,
      report: report,
    }
  end

  # Deep merge two hashes
  def deep_merge(hash1, hash2)
    result = hash1.dup
    hash2.each do |key, value|
      result[key] = if result[key].is_a?(Hash) && value.is_a?(Hash)
                      deep_merge(result[key], value)
                    else
                      value
                    end
    end
    result
  end
end
