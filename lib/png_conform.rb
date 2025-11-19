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

  # Load base validator and registry (Phase 4 optimization: lazy validator loading)
  # All validators are loaded on-demand by chunk_registry
  require_relative "png_conform/validators/base_validator"
  require_relative "png_conform/validators/chunk_registry"

  # Load services (Phase 9 - implemented)
  require_relative "png_conform/services/validation_service"
  require_relative "png_conform/services/profile_manager"

  # Load analyzers (Phase 13 - Quick Win features)
  # Analyzers are lazy-loaded on-demand in validation_service.rb (Phase 3 optimization)
  # No upfront loading needed here

  # Load reporter factory only (Phase 2 optimization: lazy reporter loading)
  # Individual reporters are loaded on-demand by the factory
  require_relative "png_conform/reporters/reporter_factory"

  # Load CLI (Phase 11 - implemented)
  require_relative "png_conform/cli"
end
