# frozen_string_literal: true

require_relative "critical/ihdr_validator"
require_relative "critical/plte_validator"
require_relative "critical/idat_validator"
require_relative "critical/iend_validator"
require_relative "ancillary/text_validator"
require_relative "ancillary/ztxt_validator"
require_relative "ancillary/itxt_validator"
require_relative "ancillary/gama_validator"
require_relative "ancillary/chrm_validator"
require_relative "ancillary/srgb_validator"
require_relative "ancillary/sbit_validator"
require_relative "ancillary/bkgd_validator"
require_relative "ancillary/iccp_validator"
require_relative "ancillary/hist_validator"
require_relative "ancillary/splt_validator"
require_relative "ancillary/trns_validator"
require_relative "ancillary/phys_validator"
require_relative "ancillary/time_validator"
require_relative "ancillary/offs_validator"
require_relative "ancillary/pcal_validator"
require_relative "ancillary/scal_validator"
require_relative "ancillary/ster_validator"
require_relative "ancillary/cicp_validator"
require_relative "ancillary/mdcv_validator"
require_relative "apng/actl_validator"
require_relative "apng/fctl_validator"
require_relative "apng/fdat_validator"
require_relative "mng/mhdr_validator"
require_relative "mng/mend_validator"
require_relative "mng/dhdr_validator"
require_relative "mng/fram_validator"
require_relative "mng/defi_validator"
require_relative "mng/back_validator"
require_relative "mng/loop_validator"
require_relative "mng/endl_validator"
require_relative "mng/term_validator"
require_relative "mng/save_validator"
require_relative "mng/seek_validator"
require_relative "mng/move_validator"
require_relative "mng/clip_validator"
require_relative "mng/show_validator"
require_relative "mng/clon_validator"
require_relative "mng/disc_validator"
require_relative "jng/jhdr_validator"
require_relative "jng/jdat_validator"
require_relative "jng/jsep_validator"

module PngConform
  module Validators
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
    class ChunkRegistry
      # Map of chunk type codes to validator classes
      VALIDATORS = {
        # Critical chunks
        "IHDR" => Critical::IhdrValidator,
        "PLTE" => Critical::PlteValidator,
        "IDAT" => Critical::IdatValidator,
        "IEND" => Critical::IendValidator,

        # Text chunks
        "tEXt" => Ancillary::TextValidator,
        "zTXt" => Ancillary::ZtxtValidator,
        "iTXt" => Ancillary::ItxtValidator,

        # Color management
        "gAMA" => Ancillary::GamaValidator,
        "cHRM" => Ancillary::ChrmValidator,
        "sRGB" => Ancillary::SrgbValidator,
        "sBIT" => Ancillary::SbitValidator,
        "bKGD" => Ancillary::BkgdValidator,
        "iCCP" => Ancillary::IccpValidator,

        # Palette support
        "hIST" => Ancillary::HistValidator,
        "sPLT" => Ancillary::SpltValidator,
        "tRNS" => Ancillary::TrnsValidator,

        # Metadata
        "pHYs" => Ancillary::PhysValidator,
        "tIME" => Ancillary::TimeValidator,
        "oFFs" => Ancillary::OffsValidator,
        "pCAL" => Ancillary::PcalValidator,
        "sCAL" => Ancillary::ScalValidator,
        "sTER" => Ancillary::SterValidator,

        # PNG 3rd edition
        "cICP" => Ancillary::CicpValidator,
        "mDCv" => Ancillary::MdcvValidator,

        # APNG (Animated PNG)
        "acTL" => Apng::ActlValidator,
        "fcTL" => Apng::FctlValidator,
        "fdAT" => Apng::FdatValidator,

        # MNG (Multiple-image Network Graphics)
        "MHDR" => Mng::MhdrValidator,
        "MEND" => Mng::MendValidator,
        "DHDR" => Mng::DhdrValidator,
        "FRAM" => Mng::FramValidator,
        "DEFI" => Mng::DefiValidator,
        "BACK" => Mng::BackValidator,
        "LOOP" => Mng::LoopValidator,
        "ENDL" => Mng::EndlValidator,
        "TERM" => Mng::TermValidator,
        "SAVE" => Mng::SaveValidator,
        "SEEK" => Mng::SeekValidator,
        "MOVE" => Mng::MoveValidator,
        "CLIP" => Mng::ClipValidator,
        "SHOW" => Mng::ShowValidator,
        "CLON" => Mng::ClonValidator,
        "DISC" => Mng::DiscValidator,

        # JNG (JPEG Network Graphics)
        "JHDR" => Jng::JhdrValidator,
        "JDAT" => Jng::JdatValidator,
        "JSEP" => Jng::JsepValidator,
      }.freeze

      class << self
        # Get validator class for a chunk type
        #
        # @param chunk_type [String] Four-character chunk type code
        # @return [Class, nil] Validator class or nil if not found
        def validator_for(chunk_type)
          VALIDATORS[chunk_type]
        end

        # Check if a validator exists for a chunk type
        #
        # @param chunk_type [String] Four-character chunk type code
        # @return [Boolean] True if validator exists
        def validator_exists?(chunk_type)
          VALIDATORS.key?(chunk_type)
        end

        # Get all registered chunk types
        #
        # @return [Array<String>] List of chunk type codes
        def chunk_types
          VALIDATORS.keys
        end

        # Get validators by category
        #
        # @param category [Symbol] Category name
        #   (:critical, :text, :color, :palette, :metadata, :png3)
        # @return [Hash] Map of chunk types to validators in category
        def validators_by_category(category)
          case category
          when :critical
            VALIDATORS.select { |k, _| %w[IHDR PLTE IDAT IEND].include?(k) }
          when :text
            VALIDATORS.select { |k, _| %w[tEXt zTXt iTXt].include?(k) }
          when :color
            VALIDATORS.select do |k, _|
              %w[gAMA cHRM sRGB sBIT bKGD iCCP].include?(k)
            end
          when :palette
            VALIDATORS.select { |k, _| %w[hIST sPLT tRNS].include?(k) }
          when :metadata
            VALIDATORS.select do |k, _|
              %w[pHYs tIME oFFs pCAL sCAL sTER].include?(k)
            end
          when :png3
            VALIDATORS.select { |k, _| %w[cICP mDCv].include?(k) }
          when :apng
            VALIDATORS.select { |k, _| %w[acTL fcTL fdAT].include?(k) }
          when :mng
            VALIDATORS.select do |k, _|
              %w[MHDR MEND DHDR FRAM DEFI BACK LOOP ENDL TERM SAVE SEEK
                 MOVE CLIP SHOW CLON DISC].include?(k)
            end
          when :jng
            VALIDATORS.select { |k, _| %w[JHDR JDAT JSEP].include?(k) }
          else
            {}
          end
        end

        # Get count of registered validators
        #
        # @return [Integer] Number of registered validators
        def count
          VALIDATORS.size
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
      end
    end
  end
end
