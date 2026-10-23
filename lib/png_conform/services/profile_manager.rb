# frozen_string_literal: true

require "yaml"
require_relative "../configuration"

module PngConform
  module Services
    # Profile manager for PNG validation profiles
    #
    # Manages validation profiles that define which chunks are required,
    # optional, or prohibited for different PNG use cases.
    #
    # Profiles can be loaded from YAML configuration files or use built-in defaults.
    #
    class ProfileManager
      # Built-in validation profiles (fallback if YAML not available)
      BUILTIN_PROFILES = {
        # Minimal valid PNG - only critical chunks
        minimal: {
          name: "Minimal",
          description: "Minimal valid PNG with only critical chunks",
          required_chunks: %w[IHDR IDAT IEND],
          optional_chunks: [],
          prohibited_chunks: [],
        },

        # Web-optimized PNG
        web: {
          name: "Web",
          description: "Optimized for web browsers",
          required_chunks: %w[IHDR IDAT IEND],
          optional_chunks: %w[
            gAMA sRGB pHYs tEXt zTXt iTXt tIME
            bKGD tRNS PLTE
          ],
          prohibited_chunks: %w[iCCP cHRM sBIT],
        },

        # Print-quality PNG
        print: {
          name: "Print",
          description: "High quality for printing",
          required_chunks: %w[IHDR IDAT IEND pHYs],
          optional_chunks: %w[
            gAMA sRGB cHRM iCCP sBIT
            tEXt zTXt iTXt tIME
            bKGD tRNS PLTE
          ],
          prohibited_chunks: [],
        },

        # Archive PNG - maximum metadata
        archive: {
          name: "Archive",
          description: "Long-term preservation with full metadata",
          required_chunks: %w[IHDR IDAT IEND tIME],
          optional_chunks: %w[
            gAMA sRGB cHRM iCCP sBIT
            pHYs tEXt zTXt iTXt
            bKGD tRNS hIST sPLT PLTE
            oFFs pCAL sCAL sTER
          ],
          prohibited_chunks: [],
        },

        # Strict PNG specification compliance
        strict: {
          name: "Strict",
          description: "Full PNG specification compliance",
          required_chunks: %w[IHDR IDAT IEND],
          optional_chunks: %w[
            PLTE
            gAMA sRGB cHRM iCCP sBIT cICP mDCv
            pHYs tEXt zTXt iTXt tIME
            bKGD tRNS hIST sPLT
            oFFs pCAL sCAL sTER
          ],
          prohibited_chunks: [],
        },

        # Default profile - permissive
        default: {
          name: "Default",
          description: "Permissive validation (all standard chunks allowed)",
          required_chunks: %w[IHDR IDAT IEND],
          optional_chunks: %w[
            PLTE
            gAMA sRGB cHRM iCCP sBIT cICP mDCv
            pHYs tEXt zTXt iTXt tIME
            bKGD tRNS hIST sPLT
            oFFs pCAL sCAL sTER
          ],
          prohibited_chunks: [],
        },
      }.freeze

      class << self
        # Get profile by name
        #
        # Loads from YAML if available, otherwise uses built-in profiles
        #
        # @param name [Symbol, String] Profile name
        # @return [Hash, nil] Profile configuration or nil if not found
        def get_profile(name)
          profiles_from_yaml[name.to_sym] || BUILTIN_PROFILES[name.to_sym]
        end

        # Check if a profile exists
        #
        # @param name [Symbol, String] Profile name
        # @return [Boolean] True if profile exists
        def profile_exists?(name)
          sym_name = name.to_sym
          profiles_from_yaml.key?(sym_name) || BUILTIN_PROFILES.key?(sym_name)
        end

        # Get all available profile names
        #
        # @return [Array<Symbol>] List of profile names
        def available_profiles
          (profiles_from_yaml.keys | BUILTIN_PROFILES.keys).uniq.sort
        end

        # Get profile information
        #
        # @param name [Symbol, String] Profile name
        # @return [Hash] Profile name and description
        def profile_info(name)
          profile = get_profile(name)
          return nil unless profile

          {
            name: profile[:name],
            description: profile[:description],
          }
        end

        # Validate chunk against profile
        #
        # Each result carries the canonical diagnostic under :diagnostic;
        # :status and :message remain as compatibility projections of it.
        #
        # @param chunk_type [String] Chunk type code
        # @param profile_name [Symbol, String] Profile name
        # @return [Hash] Validation result with status, message, diagnostic
        def validate_chunk_against_profile(chunk_type, profile_name)
          profile = get_profile(profile_name)
          unless profile
            return error_result(
              "profile.chunk.unknown-profile", "Unknown profile: #{profile_name}",
              chunk_type: chunk_type, profile: profile_name
            )
          end

          context = { chunk_type: chunk_type, profile: profile_name,
                      profile_label: profile[:name] }
          if profile[:prohibited_chunks].include?(chunk_type)
            error_result(
              "profile.chunk.prohibited",
              "#{chunk_type} chunk prohibited in #{profile[:name]} profile",
              **context,
            )
          elsif profile[:required_chunks].include?(chunk_type)
            success_result("info.profile.chunk.required-present",
                           "#{chunk_type} chunk required and present", **context)
          elsif profile[:optional_chunks].include?(chunk_type) || profile[:optional_chunks] == ["*"]
            success_result("info.profile.chunk.optional-present",
                           "#{chunk_type} chunk optional and present", **context)
          else
            warning_result(
              "profile.chunk.undefined",
              "#{chunk_type} chunk not defined in #{profile[:name]} profile",
              **context,
            )
          end
        end

        # Check required chunks for profile
        #
        # @param present_chunks [Array<String>] List of chunk types in file
        # @param profile_name [Symbol, String] Profile name
        # @return [Array<String>] List of missing required chunks
        def check_required_chunks(present_chunks, profile_name)
          profile = get_profile(profile_name)
          return [] unless profile

          profile[:required_chunks] - present_chunks
        end

        # Check prohibited chunks for profile
        #
        # @param present_chunks [Array<String>] List of chunk types in file
        # @param profile_name [Symbol, String] Profile name
        # @return [Array<String>] List of prohibited chunks present
        def check_prohibited_chunks(present_chunks, profile_name)
          profile = get_profile(profile_name)
          return [] unless profile

          present_chunks & profile[:prohibited_chunks]
        end

        # Validate file chunks against profile
        #
        # :diagnostics holds the canonical diagnostics; :errors holds their
        # messages as a compatibility projection, with :valid derived from them.
        #
        # @param chunks [Array<String>] List of chunk types in file
        # @param profile_name [Symbol, String] Profile name
        # @return [Hash] Validation results with errors, warnings, diagnostics
        def validate_file_against_profile(chunks, profile_name)
          profile = get_profile(profile_name)
          diagnostics = check_required_chunks(chunks, profile_name).map do |chunk_type|
            profile_diagnostic(
              "profile.file.required-missing",
              "Missing required chunk: #{chunk_type}",
              chunk_type: chunk_type, profile: profile_name,
              label: profile[:name]
            )
          end

          check_prohibited_chunks(chunks, profile_name).each do |chunk_type|
            diagnostics << profile_diagnostic(
              "profile.file.prohibited-present",
              "Prohibited chunk present: #{chunk_type}",
              chunk_type: chunk_type, profile: profile_name,
              label: profile[:name]
            )
          end

          errors = diagnostics.select(&:error?)
          {
            errors: errors.map(&:message),
            warnings: diagnostics.select(&:warning?).map(&:message),
            valid: errors.empty?,
            diagnostics: diagnostics,
          }
        end

        # Reload profiles from YAML
        #
        # @return [void]
        def reload_yaml_profiles!
          @profiles_from_yaml = nil
        end

        private

        # Load profiles from YAML configuration file
        #
        # @return [Hash] Profiles loaded from YAML
        def profiles_from_yaml
          @profiles_from_yaml ||= load_yaml_profiles
        end

        # Load profiles from YAML file
        #
        # @return [Hash] Loaded profiles or empty hash if file not found
        def load_yaml_profiles
          config_path = File.join(File.dirname(__FILE__),
                                  "../../config/validation_profiles.yml")
          return {} unless File.exist?(config_path)

          YAML.load_file(config_path).transform_keys(&:to_sym)
        rescue StandardError => e
          warn "Failed to load profiles from YAML: #{e.message}"
          {}
        end

        # Create success result
        #
        # @param id [String] informational catalog ID
        # @param message [String] Success message
        # @return [Hash] Result hash
        def success_result(id, message, **context)
          profile_result(:success, id, message, **context)
        end

        # Create warning result
        #
        # @param id [String] catalog ID
        # @param message [String] Warning message
        # @return [Hash] Result hash
        def warning_result(id, message, **context)
          profile_result(:warning, id, message, **context)
        end

        # Create error result
        #
        # @param id [String] catalog ID
        # @param message [String] Error message
        # @return [Hash] Result hash
        def error_result(id, message, **context)
          profile_result(:error, id, message, **context)
        end

        def profile_result(status, id, message, **context)
          {
            status: status, message: message,
            diagnostic: profile_diagnostic(
              id, message, chunk_type: context[:chunk_type],
                           profile: context[:profile],
                           label: context[:profile_label]
            )
          }
        end

        # Canonical diagnostic for a profile policy finding. The citation
        # names the profile; there is no byte offset (the finding concerns
        # the file or chunk type, not a position).
        def profile_diagnostic(id, message, chunk_type:, profile:, label: nil)
          note = "profile #{profile}"
          note += " (#{label})" if label
          Diagnostics::Builder.build(id, message, chunk_type: chunk_type,
                                                  profile: profile,
                                                  citation_note: note)
        end
      end
    end
  end
end
