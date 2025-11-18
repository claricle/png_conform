# frozen_string_literal: true

# Base class for running validation tools and measuring their performance.
#
# Provides a common interface for executing different PNG validation tools
# (png_conform, pngcheck) and collecting performance metrics.
class ToolRunner
  attr_reader :name, :command, :options

  # @param name [String] The name of the tool
  # @param command [String] The command to execute
  # @param options [Hash] Tool-specific options
  def initialize(name, command, options = {})
    @name = name
    @command = command
    @options = options
  end

  # Check if the tool is available on the system.
  #
  # @return [Boolean] True if tool is available
  def available?
    system("which #{command} > /dev/null 2>&1")
  end

  # Run the tool on a single file and measure performance.
  #
  # @param file_path [String] Path to the PNG file
  # @return [Hash] Performance metrics and results
  def run(file_path)
    raise NotImplementedError, "Subclasses must implement #run"
  end

  # Run the tool on multiple files.
  #
  # @param file_paths [Array<String>] Paths to PNG files
  # @return [Array<Hash>] Array of performance metrics
  def run_batch(file_paths)
    file_paths.map { |path| run(path) }
  end

  protected

  # Measure execution time and memory usage.
  #
  # @yield Block to measure
  # @return [Hash] Performance metrics
  def measure_performance
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    start_memory = get_memory_usage

    result = yield

    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end_memory = get_memory_usage

    {
      execution_time: ((end_time - start_time) * 1000).round(3), # milliseconds
      memory_used: end_memory - start_memory,
      peak_memory: end_memory,
      result: result
    }
  end

  # Get current memory usage in MB.
  #
  # @return [Float] Memory usage in megabytes
  def get_memory_usage
    # Get RSS (Resident Set Size) in KB, convert to MB
    rss_kb = `ps -o rss= -p #{Process.pid}`.strip.to_i
    (rss_kb / 1024.0).round(2)
  end

  # Execute a command and capture output.
  #
  # @param cmd [String] Command to execute
  # @param timeout [Integer] Timeout in seconds
  # @return [Hash] Command result with stdout, stderr, and exit status
  def execute_command(cmd, timeout: 30)
    require "open3"
    require "timeout"

    stdout, stderr, status = nil
    begin
      Timeout.timeout(timeout) do
        stdout, stderr, status = Open3.capture3(cmd)
      end
    rescue Timeout::Error
      return {
        stdout: "",
        stderr: "Command timed out after #{timeout} seconds",
        exit_code: -1,
        timed_out: true
      }
    end

    {
      stdout: stdout,
      stderr: stderr,
      exit_code: status.exitstatus,
      timed_out: false
    }
  end
end