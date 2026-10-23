# frozen_string_literal: true

require "ripper"

module PngConform
  module Spec
    # Static scan of the explicit emitter inventory (card 02).
    #
    # Finds every call site that can produce a conformance finding in the
    # in-scope source files and returns its normalized call text, so the
    # catalog spec can prove each site has exactly one catalog entry.
    module EmitterInventory
      LIB_ROOT = File.expand_path("../../lib/png_conform", __dir__)

      Site = Struct.new(:file, :line, :call, keyword_init: true)

      VALIDATOR_METHODS = %w[
        add_error add_warning add_info
        check_length check_range check_enum check_crc
      ].freeze

      # Calls that end a statement without parentheses (e.g. `check_crc`).
      BARE_FOLLOWERS = %i[on_nl on_ignored_nl on_semicolon on_comma on_rparen
                          on_op on_rbrace].freeze
      OPENERS = %i[on_lparen on_lbracket on_lbrace on_tlambeg].freeze
      CLOSERS = %i[on_rparen on_rbracket on_rbrace].freeze
      BARE_KEYWORDS = %w[if unless and or then end].freeze

      module_function

      # @return [Array<String>] validator paths relative to lib/png_conform
      def registered_validator_files
        Validators::ChunkRegistry::VALIDATOR_PATHS.values.map do |path, *|
          "validators/#{path}.rb"
        end
      end

      # @return [Hash{String=>Hash}] file => scan options
      def sources
        validators = registered_validator_files.to_h do |f|
          [f, { methods: VALIDATOR_METHODS, dotted: false }]
        end
        validators.merge(
          "validators/base_validator.rb" =>
            { methods: VALIDATOR_METHODS, dotted: false },
          "services/validation_orchestrator.rb" =>
            { methods: %w[add_error], dotted: true },
          "services/chunk_processor.rb" =>
            { methods: %w[add_error], dotted: true },
          "services/profile_manager.rb" =>
            { methods: %w[error_result warning_result success_result],
              dotted: false, appends: true },
        )
      end

      def all_sites
        sources.flat_map { |file, opts| scan(file, **opts) }
      end

      def scan(file, methods:, dotted:, appends: false)
        source = File.read(File.join(LIB_ROOT, file))
        sites = scan_calls(file, source, methods, dotted)
        sites += scan_appends(file, source) if appends
        sites.sort_by(&:line)
      end

      def scan_calls(file, source, methods, dotted)
        tokens = Ripper.lex(source).reject { |t| t[1] == :on_comment }
        sites = []
        tokens.each_with_index do |tok, i|
          next unless tok[1] == :on_ident && methods.include?(tok[2])

          prev = significant(tokens, i, -1)
          next if prev && prev[1] == :on_kw && prev[2] == "def"
          next if prev && prev[1] == :on_period && !dotted

          call = call_text(tokens, i, file)
          next if pass_through?(call)

          sites << Site.new(file: file, line: tok[0][0], call: normalize(call))
        end
        sites
      end

      def scan_appends(file, source)
        source.each_line.with_index(1).filter_map do |line, no|
          next unless (m = line.match(/(results\[:(?:errors|warnings)\]\s*<<\s*.+)$/))

          Site.new(file: file, line: no, call: normalize(m[1]))
        end
      end

      def significant(tokens, index, step)
        index += step
        index += step while tokens[index] && tokens[index][1] == :on_sp
        index.negative? ? nil : tokens[index]
      end

      def call_text(tokens, index, file)
        nxt = significant(tokens, index, 1)
        return tokens[index][2] if bare?(nxt)
        unless nxt[1] == :on_lparen
          raise "#{file}:#{tokens[index][0][0]}: unsupported call form " \
                "for #{tokens[index][2]}"
        end

        depth = 0
        text = +tokens[index][2]
        tokens[(index + 1)..].each do |t|
          text << t[2]
          depth += 1 if OPENERS.include?(t[1])
          depth -= 1 if CLOSERS.include?(t[1])
          break if depth.zero?
        end
        text
      end

      def bare?(token)
        return true if token.nil?
        return true if BARE_FOLLOWERS.include?(token[1])

        token[1] == :on_kw && BARE_KEYWORDS.include?(token[2])
      end

      # `add_error(message, severity: :warning)` forwards a caller message;
      # the caller's own site is what gets inventoried.
      def pass_through?(call)
        call.match?(/\Aadd_error\(\s*message\s*,\s*severity:/)
      end

      def normalize(text)
        text.gsub(/"\s*\\\n\s*"/, "")
          .gsub(/\s+/, " ")
          .gsub(/\(\s+/, "(")
          .gsub(/,\s*\)/, ")")
          .strip
      end
    end
  end
end
