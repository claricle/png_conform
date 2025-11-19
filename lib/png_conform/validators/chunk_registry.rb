# frozen_string_literal: true

module PngConform
  module Validators
    # Define validator category modules upfront for proper namespace resolution
    module Critical; end
    module Ancillary; end
    module Apng; end
    module Mng; end
    module Jng; end

    # Registry of chunk types to their corresponding validator classes
    #
    # This class maintains a mapping between PNG chunk type codes and
    # their validator implementations. It follows the Registry pattern
    # to provide centralized validator discovery and instantiation.
    #
    # The registry is organized by chunk categories:
    # - Critical chunks (IHDR, PLTE, IDAT, IEND)
    # - Text chunks (tEXt, zTXt, iTXt)
    # - Color management (gAMA, cHRM, sRGB, sBIT, bKGD, iCCP)
    # - Palette support (hIST, sPLT, tRNS)
    # - Metadata (pHYs, tIME, oFFs, pCAL, sCAL, sTER)
    # - PNG 3rd edition (cICP, mDCv)
    # - APNG (acTL, fcTL, fdAT)
    # - MNG (MHDR, MEND, DHDR, FRAM, DEFI, BACK, LOOP, ENDL, etc.)
    # - JNG (JHDR, JDAT, JSEP)
    #
    # Validators are loaded lazily on-demand to improve startup performance.
    #
    class ChunkRegistry
      # Map of chunk type codes to validator file paths and class names
      # Format: [file_path, module_path, class_name]
      VALIDATOR_PATHS = {
        # Critical chunks
        "IHDR" => ["critical/ihdr_validator", "Critical", "IhdrValidator"],
        "PLTE" => ["critical/plte_validator", "Critical", "PlteValidator"],
        "IDAT" => ["critical/idat_validator", "Critical", "IdatValidator"],
        "IEND" => ["critical/iend_validator", "Critical", "IendValidator"],

        # Text chunks
        "tEXt" => ["ancillary/text_validator", "Ancillary", "TextValidator"],
        "zTXt" => ["ancillary/ztxt_validator", "Ancillary", "ZtxtValidator"],
        "iTXt" => ["ancillary/itxt_validator", "Ancillary", "ItxtValidator"],

        # Color management
        "gAMA" => ["ancillary/gama_validator", "Ancillary", "GamaValidator"],
        "cHRM" => ["ancillary/chrm_validator", "Ancillary", "ChrmValidator"],
        "sRGB" => ["ancillary/srgb_validator", "Ancillary", "SrgbValidator"],
        "sBIT" => ["ancillary/sbit_validator", "Ancillary", "SbitValidator"],
        "bKGD" => ["ancillary/bkgd_validator", "Ancillary", "BkgdValidator"],
        "iCCP" => ["ancillary/iccp_validator", "Ancillary", "IccpValidator"],

        # Palette support
        "hIST" => ["ancillary/hist_validator", "Ancillary", "HistValidator"],
        "sPLT" => ["ancillary/splt_validator", "Ancillary", "SpltValidator"],
        "tRNS" => ["ancillary/trns_validator", "Ancillary", "TrnsValidator"],

        # Metadata
        "pHYs" => ["ancillary/phys_validator", "Ancillary", "PhysValidator"],
        "tIME" => ["ancillary/time_validator", "Ancillary", "TimeValidator"],
        "oFFs" => ["ancillary/offs_validator", "Ancillary", "OffsValidator"],
        "pCAL" => ["ancillary/pcal_validator", "Ancillary", "PcalValidator"],
        "sCAL" => ["ancillary/scal_validator", "Ancillary", "ScalValidator"],
        "sTER" => ["ancillary/ster_validator", "Ancillary", "SterValidator"],

        # PNG 3rd edition
        "cICP" => ["ancillary/cicp_validator", "Ancillary", "CicpValidator"],
        "mDCv" => ["ancillary/mdcv_validator", "Ancillary", "MdcvValidator"],

        # APNG (Animated PNG)
        "acTL" => ["apng/actl_validator", "Apng", "ActlValidator"],
        "fcTL" => ["apng/fctl_validator", "Apng", "FctlValidator"],
        "fdAT" => ["apng/fdat_validator", "Apng", "FdatValidator"],

        # MNG (Multiple-image Network Graphics)
        "MHDR" => ["mng/mhdr_validator", "Mng", "MhdrValidator"],
        "MEND" => ["mng/mend_validator", "Mng", "MendValidator"],
        "DHDR" => ["mng/dhdr_validator", "Mng", "DhdrValidator"],
        "FRAM" => ["mng/fram_validator", "Mng", "FramValidator"],
        "DEFI" => ["mng/defi_validator", "Mng", "DefiValidator"],
        "BACK" => ["mng/back_validator", "Mng", "BackValidator"],
        "LOOP" => ["mng/loop_validator", "Mng", "LoopValidator"],
        "ENDL" => ["mng/endl_validator", "Mng", "EndlValidator"],
        "TERM" => ["mng/term_validator", "Mng", "TermValidator"],
        "SAVE" => ["mng/save_validator", "Mng", "SaveValidator"],
        "SEEK" => ["mng/seek_validator", "Mng", "SeekValidator"],
        "MOVE" => ["mng/move_validator", "Mng", "MoveValidator"],
        "CLIP" => ["mng/clip_validator", "Mng", "ClipValidator"],
        "SHOW" => ["mng/show_validator", "Mng", "ShowValidator"],
        "CLON" => ["mng/clon_validator", "Mng", "ClonValidator"],
        "DISC" => ["mng/disc_validator", "Mng", "DiscValidator"],

        # JNG (JPEG Network Graphics)
        "JHDR" => ["jng/jhdr_validator", "Jng", "JhdrValidator"],
        "JDAT" => ["jng/jdat_validator", "Jng", "JdatValidator"],
        "JSEP" => ["jng/jsep_validator", "Jng", "JsepValidator"],
      }.freeze

      class << self
        # Get validator class for a chunk type (with lazy loading)
        #
        # @param chunk_type [String] Four-character chunk type code
        # @return [Class, nil] Validator class or nil if not found
        def validator_for(chunk_type)
          # Return cached validator if already loaded
          return loaded_validators[chunk_type] if loaded_validators.key?(chunk_type)

          # Check if validator path exists
          validator_info = VALIDATOR_PATHS[chunk_type]
          return nil unless validator_info

          # Load validator on-demand
          load_validator(chunk_type, validator_info)
        end

        # Check if a validator exists for a chunk type
        #
        # @param chunk_type [String] Four-character chunk type code
        # @return [Boolean] True if validator exists
        def validator_exists?(chunk_type)
          VALIDATOR_PATHS.key?(chunk_type)
        end

        # Get all registered chunk types
        #
        # @return [Array<String>] List of chunk type codes
        def chunk_types
          VALIDATOR_PATHS.keys
        end

        # Get validators by category
        #
        # @param category [Symbol] Category name
        #   (:critical, :text, :color, :palette, :metadata, :png3)
        # @return [Hash] Map of chunk types to validators in category
        def validators_by_category(category)
          chunk_types = case category
                        when :critical
                          %w[IHDR PLTE IDAT IEND]
                        when :text
                          %w[tEXt zTXt iTXt]
                        when :color
                          %w[gAMA cHRM sRGB sBIT bKGD iCCP]
                        when :palette
                          %w[hIST sPLT tRNS]
                        when :metadata
                          %w[pHYs tIME oFFs pCAL sCAL sTER]
                        when :png3
                          %w[cICP mDCv]
                        when :apng
                          %w[acTL fcTL fdAT]
                        when :mng
                          %w[MHDR MEND DHDR FRAM DEFI BACK LOOP ENDL TERM SAVE SEEK
                             MOVE CLIP SHOW CLON DISC]
                        when :jng
                          %w[JHDR JDAT JSEP]
                        else
                          []
                        end

          # Load validators for this category
          chunk_types.each_with_object({}) do |chunk_type, result|
            validator = validator_for(chunk_type)
            result[chunk_type] = validator if validator
          end
        end

        # Get count of registered validators
        #
        # @return [Integer] Number of registered validators
        def count
          VALIDATOR_PATHS.size
        end

        # Create validator instance for a chunk
        #
        # @param chunk [Object] Chunk object with type and data
        # @param context [ValidationContext] Validation context
        # @return [BaseValidator, nil] Validator instance or nil
        def create_validator(chunk, context)
          validator_class = validator_for(chunk.type)
          return nil unless validator_class

          validator_class.new(chunk, context)
        end

        private

        # Cache for loaded validator classes
        def loaded_validators
          @loaded_validators ||= {}
        end

        # Load a validator class on-demand
        #
        # @param chunk_type [String] Chunk type code
        # @param validator_info [Array] [file_path, module_name, class_name]
        # @return [Class, nil] Loaded validator class
        def load_validator(chunk_type, validator_info)
          file_path, module_name, class_name = validator_info

          # Require the validator file
          require_relative file_path

          # Resolve the constant (e.g., Critical::IhdrValidator)
          validator_class = Validators.const_get(module_name).const_get(class_name)

          # Cache and return
          loaded_validators[chunk_type] = validator_class
        rescue NameError, LoadError => e
          warn "Failed to load validator for #{chunk_type}: #{e.message}"
          loaded_validators[chunk_type] = nil
        end
      end
    end
  end
end
