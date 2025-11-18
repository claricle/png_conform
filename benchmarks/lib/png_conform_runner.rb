# frozen_string_literal: true

require_relative "tool_runner"

# Runner for the png_conform validation tool.
#
# Executes png_conform CLI and collects performance metrics.
class PngConformRunner < ToolRunner
  def initialize(options = {})
    # Use the exe/png_conform in the project root
    command = File.expand_path("../../exe/png_conform", __dir__)
    super("png_conform", command, options)
  end

  # Run png_conform on a single file.
  #
  # @param file_path [String] Path to the PNG file
  # @return [Hash] Performance metrics and validation results
  def run(file_path)
    return error_result("File not found: #{file_path}") unless File.exist?(file_path)

    measure_performance do
      cli_options = build_cli_options
      cmd = "#{command} check #{cli_options} #{file_path}"
      result = execute_command(cmd)

      {
        file: file_path,
        tool: name,
        success: result[:exit_code].zero?,
        exit_code: result[:exit_code],
        stdout: result[:stdout],
        stderr: result[:stderr],
        timed_out: result[:timed_out]
      }
    end
  end

  private

  def build_cli_options
    cli_opts = options[:cli_options] || []

    # Add --quiet by default to reduce output parsing overhead
    cli_opts << "--quiet" unless cli_opts.include?("--quiet") ||
                                  cli_opts.include?("-q") ||
                                  cli_opts.include?("--verbose")

    cli_opts.join(" ")
  end

  def error_result(message)
    {
      execution_time: 0,
      memory_used: 0,
      peak_memory: 0,
      result: {
        file: nil,
        tool: name,
        success: false,
        exit_code: -1,
        stdout: "",
        stderr: message,
        timed_out: false
      }
    }
  end
end