# frozen_string_literal: true

require "bindata"
require "lutaml/model"
require "thor"

require_relative "png_conform/version"

# Configure lutaml-model for YAML/JSON serialization
Lutaml::Model::Config.configure do |config|
  config.yaml_adapter_type = :standard_yaml
  config.json_adapter_type = :standard_json
end

module PngConform
  class Error < StandardError; end

  class ValidationError < Error; end

  class ParseError < Error; end

  # Load BinData structures (Phase 2 - implemented)
  require_relative "png_conform/bindata/chunk_structure"
  require_relative "png_conform/bindata/png_file"
  require_relative "png_conform/bindata/mng_file"
  require_relative "png_conform/bindata/jng_file"

  # Load readers (Phase 2 - implemented)
  require_relative "png_conform/readers/streaming_reader"
  require_relative "png_conform/readers/full_load_reader"

  # Load domain models (Phase 3 & 10 - implemented)
  require_relative "png_conform/models/decoded_chunk_data"
  require_relative "png_conform/models/chunk"
  require_relative "png_conform/models/validation_error"
  require_relative "png_conform/models/chunk_info"
  require_relative "png_conform/models/image_info"
  require_relative "png_conform/models/compression_info"
  require_relative "png_conform/models/file_info"
  require_relative "png_conform/models/validation_result"
  require_relative "png_conform/models/file_analysis"

  # Load validators (Phase 4 & 5 - implemented)
  require_relative "png_conform/validators/base_validator"

  # Critical validators
  require_relative "png_conform/validators/critical/ihdr_validator"
  require_relative "png_conform/validators/critical/plte_validator"
  require_relative "png_conform/validators/critical/idat_validator"
  require_relative "png_conform/validators/critical/iend_validator"

  # Ancillary validators
  require_relative "png_conform/validators/ancillary/gama_validator"
  require_relative "png_conform/validators/ancillary/trns_validator"
  require_relative "png_conform/validators/ancillary/chrm_validator"
  require_relative "png_conform/validators/ancillary/srgb_validator"
  require_relative "png_conform/validators/ancillary/iccp_validator"
  require_relative "png_conform/validators/ancillary/text_validator"
  require_relative "png_conform/validators/ancillary/ztxt_validator"
  require_relative "png_conform/validators/ancillary/itxt_validator"
  require_relative "png_conform/validators/ancillary/bkgd_validator"
  require_relative "png_conform/validators/ancillary/phys_validator"
  require_relative "png_conform/validators/ancillary/sbit_validator"
  require_relative "png_conform/validators/ancillary/splt_validator"
  require_relative "png_conform/validators/ancillary/hist_validator"
  require_relative "png_conform/validators/ancillary/time_validator"
  require_relative "png_conform/validators/ancillary/offs_validator"
  require_relative "png_conform/validators/ancillary/pcal_validator"
  require_relative "png_conform/validators/ancillary/scal_validator"
  require_relative "png_conform/validators/ancillary/ster_validator"
  require_relative "png_conform/validators/ancillary/cicp_validator"
  require_relative "png_conform/validators/ancillary/mdcv_validator"

  # Load services (Phase 9 - implemented)
  require_relative "png_conform/validators/chunk_registry"
  require_relative "png_conform/services/validation_service"
  require_relative "png_conform/services/profile_manager"

  # Load analyzers (Phase 13 - Quick Win features)
  require_relative "png_conform/analyzers/optimization_analyzer"
  require_relative "png_conform/analyzers/metrics_analyzer"
  require_relative "png_conform/analyzers/resolution_analyzer"
  require_relative "png_conform/analyzers/comparison_analyzer"

  # Load reporters (Phase 10 & 7 - implemented)
  require_relative "png_conform/reporters/visual_elements"
  require_relative "png_conform/reporters/base_reporter"
  require_relative "png_conform/reporters/summary_reporter"
  require_relative "png_conform/reporters/verbose_reporter"
  require_relative "png_conform/reporters/very_verbose_reporter"
  require_relative "png_conform/reporters/quiet_reporter"
  require_relative "png_conform/reporters/palette_reporter"
  require_relative "png_conform/reporters/text_reporter"
  require_relative "png_conform/reporters/color_reporter"
  require_relative "png_conform/reporters/yaml_reporter"
  require_relative "png_conform/reporters/json_reporter"
  require_relative "png_conform/reporters/reporter_factory"

  # Load CLI (Phase 11 - implemented)
  require_relative "png_conform/cli"
end
