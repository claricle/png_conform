# frozen_string_literal: true

# Collects and analyzes performance metrics from benchmark runs.
#
# Tracks execution time, memory usage, throughput, and calculates
# statistical measures for comparison between tools.
class MetricsCollector
  attr_reader :runs

  def initialize
    @runs = []
  end

  # Record a single benchmark run.
  #
  # @param tool [String] Name of the tool
  # @param file [String] File path
  # @param metrics [Hash] Performance metrics
  def record_run(tool, file, metrics)
    @runs << {
      tool: tool,
      file: file,
      execution_time: metrics[:execution_time],
      memory_used: metrics[:memory_used],
      peak_memory: metrics[:peak_memory],
      success: metrics[:result][:success],
      exit_code: metrics[:result][:exit_code],
      timed_out: metrics[:result][:timed_out],
      timestamp: Time.now,
    }
  end

  # Get all runs for a specific tool.
  #
  # @param tool [String] Tool name
  # @return [Array<Hash>] Runs for the tool
  def runs_for_tool(tool)
    @runs.select { |run| run[:tool] == tool }
  end

  # Calculate statistics for a tool.
  #
  # @param tool [String] Tool name
  # @return [Hash] Statistical measures
  def calculate_statistics(tool)
    tool_runs = runs_for_tool(tool)
    return nil if tool_runs.empty?

    execution_times = tool_runs.filter_map { |r| r[:execution_time] }
    memory_values = tool_runs.filter_map { |r| r[:peak_memory] }

    {
      tool: tool,
      total_runs: tool_runs.size,
      successful_runs: tool_runs.count { |r| r[:success] },
      failed_runs: tool_runs.count { |r| !r[:success] },
      timeouts: tool_runs.count { |r| r[:timed_out] },
      execution_time: calculate_stats(execution_times),
      memory: calculate_stats(memory_values),
      throughput: calculate_throughput(tool_runs),
    }
  end

  # Compare two tools.
  #
  # @param tool1 [String] First tool name
  # @param tool2 [String] Second tool name
  # @return [Hash] Comparison results
  def compare_tools(tool1, tool2)
    stats1 = calculate_statistics(tool1)
    stats2 = calculate_statistics(tool2)

    return nil if stats1.nil? || stats2.nil?

    time1 = stats1[:execution_time][:mean]
    time2 = stats2[:execution_time][:mean]
    mem1 = stats1[:memory][:mean]
    mem2 = stats2[:memory][:mean]

    faster_tool = time1 < time2 ? tool1 : tool2
    time_diff_pct = ((time1 - time2).abs / [time1, time2].min * 100).round(1)
    time_multiplier = ([time1, time2].max / [time1, time2].min).round(2)

    memory_efficient = mem1 < mem2 ? tool1 : tool2
    mem_diff_pct = ((mem1 - mem2).abs / [mem1, mem2].min * 100).round(1)
    mem_multiplier = ([mem1, mem2].max / [mem1, mem2].min).round(2)

    {
      tool1: tool1,
      tool2: tool2,
      faster_tool: faster_tool,
      time_difference_percent: time_diff_pct,
      time_multiplier: time_multiplier,
      memory_efficient_tool: memory_efficient,
      memory_difference_percent: mem_diff_pct,
      memory_multiplier: mem_multiplier,
      stats: {
        tool1 => stats1,
        tool2 => stats2,
      },
    }
  end

  # Export raw data for external analysis.
  #
  # @return [Array<Hash>] All run data
  def export_raw_data
    @runs
  end

  # Get summary statistics across all tools.
  #
  # @return [Hash] Summary data
  def summary
    tools = @runs.map { |r| r[:tool] }.uniq

    {
      total_runs: @runs.size,
      tools: tools,
      files_tested: @runs.map { |r| r[:file] }.uniq.size,
      tool_statistics: tools.filter_map { |tool| calculate_statistics(tool) },
    }
  end

  private

  # Calculate statistical measures for a dataset.
  #
  # @param values [Array<Numeric>] Data values
  # @return [Hash] Statistical measures
  def calculate_stats(values)
    return nil if values.empty?

    sorted = values.sort
    size = values.size

    {
      mean: (values.sum / size.to_f).round(3),
      median: calculate_median(sorted),
      std_dev: calculate_std_dev(values).round(3),
      min: sorted.first.round(3),
      max: sorted.last.round(3),
      count: size,
    }
  end

  # Calculate median value.
  #
  # @param sorted_values [Array<Numeric>] Sorted array
  # @return [Float] Median value
  def calculate_median(sorted_values)
    size = sorted_values.size
    mid = size / 2

    if size.even?
      ((sorted_values[mid - 1] + sorted_values[mid]) / 2.0).round(3)
    else
      sorted_values[mid].round(3)
    end
  end

  # Calculate standard deviation.
  #
  # @param values [Array<Numeric>] Data values
  # @return [Float] Standard deviation
  def calculate_std_dev(values)
    return 0.0 if values.size <= 1

    mean = values.sum / values.size.to_f
    variance = values.sum { |v| (v - mean)**2 } / values.size.to_f
    Math.sqrt(variance)
  end

  # Calculate throughput metrics.
  #
  # @param runs [Array<Hash>] Run data
  # @return [Hash] Throughput metrics
  def calculate_throughput(runs)
    successful = runs.select { |r| r[:success] }
    return nil if successful.empty?

    total_time = # Convert to seconds
      successful.sum do |r|
        r[:execution_time]
      end / 1000.0
    files_count = successful.size

    {
      files_per_second: (files_count / total_time).round(2),
      avg_time_per_file: (total_time / files_count * 1000).round(3), # milliseconds
    }
  end
end
