# frozen_string_literal: true

# The analysis behind the structured-diagnostics example in
# docs/CLI_OPTIONS.adoc; documented_report_spec.rb pins the docs to it.
module DocumentedReportExample
  module_function

  def analysis
    result = PngConform::Models::ValidationResult.new(
      filename: "corrupted.png", file_type: "PNG", file_size: 1024,
      crc_errors_count: 1
    )
    result.add_error(crc_error)
    result.warning("Missing recommended chunk gAMA",
                   error_type: "policy")
    PngConform::Models::FileAnalysis.new(
      file_path: "corrupted.png", file_size: 1024, file_type: "PNG",
      validation_result: result
    )
  end

  def crc_error
    PngConform::Diagnostics::Builder.build(
      "png.IDAT.crc", "CRC error in IDAT chunk",
      chunk_type: "IDAT", offset: 33, chunk_index: 2, field: "crc",
      expected: "0x12345678", actual: "0x87654321"
    )
  end
end
