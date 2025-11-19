# frozen_string_literal: true

require "json"
require "csv"

# Generates benchmark reports in multiple formats.
#
# Supports text, JSON, CSV, and Markdown output formats with
# detailed performance comparisons and statistics.
class ReportGenerator
  attr_reader :metrics_collector, :config

  def initialize(metrics_collector, config = {})
    @metrics_collector = metrics_collector
    @config = config
  end

  # Generate report in specified format.
  #
  # @param format [String] Output format: text, json, csv, markdown
  # @return [String] Formatted report
  def generate(format = "text")
    case format.to_s.downcase
    when "json"
      generate_json
    when "csv"
      generate_csv
    when "markdown", "md"
      generate_markdown
    else
      generate_text
    end
  end

  private

  # Generate text report with tables and colors.
  def generate_text
    summary = metrics_collector.summary
    tools = summary[:tools]

    return "No benchmark data available.\n" if tools.empty?

    output = []
    output << "=" * 80
    output << "PNG Validation Tool Benchmark Comparison"
    output << "=" * 80
    output << ""
    output << "Configuration:"
    output << "  Files tested:     #{summary[:files_tested]} PNG files"
    output << "  Total runs:       #{summary[:total_runs]}"
    output << ""

    # Tool availability
    output << "Tools:"
    tools.each do |tool|
      stats = metrics_collector.calculate_statistics(tool)
      output << "  #{tool}: #{stats[:successful_runs]}/#{stats[:total_runs]} successful"
    end
    output << ""

    # Performance comparison (if we have 2 tools)
    if tools.size == 2
      comparison = metrics_collector.compare_tools(tools[0], tools[1])
      output << "-" * 80
      output << "PERFORMANCE SUMMARY"
      output << "-" * 80
      output << ""
      output << format_comparison_table(comparison)
      output << ""
      output << format_winner_summary(comparison)
      output << ""
    end

    # Detailed statistics per tool
    output << "-" * 80
    output << "DETAILED STATISTICS"
    output << "-" * 80
    output << ""

    tools.each do |tool|
      stats = metrics_collector.calculate_statistics(tool)
      output << format_tool_statistics(stats)
      output << ""
    end

    output.join("\n")
  end

  # Generate JSON report.
  def generate_json
    summary = metrics_collector.summary
    tools = summary[:tools]

    data = {
      benchmark_info: {
        timestamp: Time.now.iso8601,
        files_tested: summary[:files_tested],
        total_runs: summary[:total_runs],
        tools: tools,
      },
      tool_statistics: summary[:tool_statistics],
      raw_data: config[:include_raw_data] ? metrics_collector.export_raw_data : nil,
    }.compact

    # Add comparison if we have 2 tools
    if tools.size == 2
      data[:comparison] = metrics_collector.compare_tools(tools[0], tools[1])
    end

    JSON.pretty_generate(data)
  end

  # Generate CSV report.
  def generate_csv
    runs = metrics_collector.export_raw_data

    CSV.generate do |csv|
      csv << ["Tool", "File", "Execution Time (ms)", "Peak Memory (MB)",
              "Success", "Exit Code", "Timed Out", "Timestamp"]

      runs.each do |run|
        csv << [
          run[:tool],
          run[:file],
          run[:execution_time],
          run[:peak_memory],
          run[:success],
          run[:exit_code],
          run[:timed_out],
          run[:timestamp].iso8601,
        ]
      end
    end
  end

  # Generate Markdown report.
  def generate_markdown
    summary = metrics_collector.summary
    tools = summary[:tools]

    return "# No benchmark data available\n" if tools.empty?

    output = []
    output << "# PNG Validation Tool Benchmark Comparison"
    output << ""
    output << "## Configuration"
    output << ""
    output << "- **Files tested**: #{summary[:files_tested]} PNG files"
    output << "- **Total runs**: #{summary[:total_runs]}"
    output << "- **Tools**: #{tools.join(', ')}"
    output << ""

    # Performance comparison
    if tools.size == 2
      comparison = metrics_collector.compare_tools(tools[0], tools[1])
      output << "## Performance Summary"
      output << ""
      output << format_markdown_comparison(comparison)
      output << ""
    end

    # Statistics per tool
    output << "## Detailed Statistics"
    output << ""

    tools.each do |tool|
      stats = metrics_collector.calculate_statistics(tool)
      output << format_markdown_statistics(stats)
      output << ""
    end

    output.join("\n")
  end

  # Format comparison table for text output.
  def format_comparison_table(comparison)
    lines = []
    lines << sprintf("%-15s %12s %12s %12s %8s",
                     "Tool", "Avg Time", "Files/sec", "Peak Memory", "Winner")
    lines << "-" * 80

    [comparison[:tool1], comparison[:tool2]].each do |tool|
      stats = comparison[:stats][tool]
      is_winner = tool == comparison[:faster_tool]

      # Handle nil throughput gracefully
      files_per_sec = stats[:throughput]&.[](:files_per_second) || 0.0

      lines << sprintf("%-15s %10.1fms %10.1f/s %10.1f MB %8s",
                       tool,
                       stats[:execution_time][:mean],
                       files_per_sec,
                       stats[:memory][:mean],
                       is_winner ? "✓" : "")
    end

    lines.join("\n")
  end

  # Format winner summary.
  def format_winner_summary(comparison)
    lines = []
    lines << "Performance Difference:"
    lines << "  #{comparison[:faster_tool]} is #{comparison[:time_multiplier]}x faster " \
             "(#{comparison[:time_difference_percent]}% faster)"
    lines << "  #{comparison[:memory_efficient_tool]} uses #{comparison[:memory_multiplier]}x less memory " \
             "(#{comparison[:memory_difference_percent]}% less)"
    lines.join("\n")
  end

  # Format tool statistics for text output.
  def format_tool_statistics(stats)
    lines = []
    lines << "#{stats[:tool]}:"
    lines << "  Runs:        #{stats[:successful_runs]}/#{stats[:total_runs]} successful"
    lines << "  Timeouts:    #{stats[:timeouts]}" if stats[:timeouts].positive?
    lines << ""
    lines << "  Execution Time:"
    lines << "    Mean:      #{stats[:execution_time][:mean]}ms"
    lines << "    Median:    #{stats[:execution_time][:median]}ms"
    lines << "    Std Dev:   #{stats[:execution_time][:std_dev]}ms"
    lines << "    Min:       #{stats[:execution_time][:min]}ms"
    lines << "    Max:       #{stats[:execution_time][:max]}ms"
    lines << ""
    lines << "  Memory Usage:"
    lines << "    Mean:      #{stats[:memory][:mean]} MB"
    lines << "    Median:    #{stats[:memory][:median]} MB"
    lines << "    Min:       #{stats[:memory][:min]} MB"
    lines << "    Max:       #{stats[:memory][:max]} MB"

    # Handle nil throughput gracefully
    if stats[:throughput]
      lines << ""
      lines << "  Throughput:"
      lines << "    Files/sec: #{stats[:throughput][:files_per_second]}"
      lines << "    Time/file: #{stats[:throughput][:avg_time_per_file]}ms"
    end

    lines.join("\n")
  end

  # Format comparison for markdown.
  def format_markdown_comparison(comparison)
    lines = []
    lines << "| Metric | #{comparison[:tool1]} | #{comparison[:tool2]} | Winner |"
    lines << "|--------|----------|----------|--------|"

    stats1 = comparison[:stats][comparison[:tool1]]
    stats2 = comparison[:stats][comparison[:tool2]]

    # Handle nil throughput gracefully
    fps1 = stats1[:throughput]&.[](:files_per_second) || "N/A"
    fps2 = stats2[:throughput]&.[](:files_per_second) || "N/A"

    lines << "| Avg Time | #{stats1[:execution_time][:mean]}ms | " \
             "#{stats2[:execution_time][:mean]}ms | " \
             "#{comparison[:faster_tool]} |"
    lines << "| Files/sec | #{fps1} | #{fps2} | " \
             "#{comparison[:faster_tool]} |"
    lines << "| Peak Memory | #{stats1[:memory][:mean]} MB | " \
             "#{stats2[:memory][:mean]} MB | " \
             "#{comparison[:memory_efficient_tool]} |"
    lines << ""
    lines << "**Performance:** #{comparison[:faster_tool]} is " \
             "#{comparison[:time_multiplier]}x faster " \
             "(#{comparison[:time_difference_percent]}% improvement)"
    lines << ""
    lines << "**Memory:** #{comparison[:memory_efficient_tool]} uses " \
             "#{comparison[:memory_multiplier]}x less memory " \
             "(#{comparison[:memory_difference_percent]}% improvement)"

    lines.join("\n")
  end

  # Format statistics for markdown.
  def format_markdown_statistics(stats)
    lines = []
    lines << "### #{stats[:tool]}"
    lines << ""
    lines << "- **Successful runs**: #{stats[:successful_runs]}/#{stats[:total_runs]}"
    lines << "- **Timeouts**: #{stats[:timeouts]}" if stats[:timeouts].positive?
    lines << ""
    lines << "**Execution Time:**"
    lines << "- Mean: #{stats[:execution_time][:mean]}ms"
    lines << "- Median: #{stats[:execution_time][:median]}ms"
    lines << "- Range: #{stats[:execution_time][:min]}ms - #{stats[:execution_time][:max]}ms"
    lines << ""
    lines << "**Memory Usage:**"
    lines << "- Mean: #{stats[:memory][:mean]} MB"
    lines << "- Range: #{stats[:memory][:min]} MB - #{stats[:memory][:max]} MB"

    # Handle nil throughput gracefully
    if stats[:throughput]
      lines << ""
      lines << "**Throughput:** #{stats[:throughput][:files_per_second]} files/sec"
    end

    lines.join("\n")
  end
end
