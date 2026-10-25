# frozen_string_literal: true

require "png_conform/diagnostics/golden_generator"

module PngConform
  # Scratch-corpus adapter; all behavior lives in the production generator.
  class DiagnosticCorpus < Diagnostics::GoldenGenerator
    def initialize(root)
      super(root: root)
    end
  end
end
