# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"
require "tempfile"
require "yaml"
require_relative "../../support/emitter_inventory"

RSpec.describe PngConform::Diagnostics::Catalog do
  let(:inventory) { PngConform::Spec::EmitterInventory }
  let(:catalog) { described_class.default }
  let(:root) { File.expand_path("../../..", __dir__) }
  let(:data) { YAML.safe_load_file(described_class::DEFAULT_PATH) }
  let(:sites) { inventory.all_sites }

  # Catalog.load needs a path, so write the (possibly altered) document out.
  def load_document(document)
    Tempfile.create(["diagnostics", ".yml"]) do |file|
      file.write(document.is_a?(String) ? document : YAML.dump(document))
      file.flush
      described_class.load(file.path)
    end
  end

  # Sites without exactly the cataloged number of matching emitter entries.
  def text_of(path)
    File.binread(path).force_encoding(Encoding::UTF_8).scrub
  end

  def uncovered_sites(catalog, sites)
    claimed = catalog.flat_map do |req|
      req.emitters.map { |e| [e.file, e.call] }
    end
    sites.group_by { |s| [s.file, s.call] }.reject do |key, group|
      claimed.count(key) == 1 && catalog.any? do |req|
        req.emitters.any? { |e| [e.file, e.call] == key && e.sites == group.size }
      end
    end.keys
  end

  describe "schema" do
    it "loads the shipped catalog with specifications and entries" do
      expect(catalog.specifications.keys).to include("iso15948", "apng", "mng", "jng", "profile")
      expect(catalog.requirements).not_to be_empty
      expect(catalog.informational).not_to be_empty
    end

    it "uses known formats, kinds and severities on every entry" do
      expect(catalog.map(&:format) - described_class::FORMATS).to be_empty
      expect(catalog.map(&:kind) - described_class::KINDS).to be_empty
      expect(catalog.map(&:severity) - described_class::SEVERITIES).to be_empty
    end

    it "gives every ID a stable dotted shape" do
      bad = catalog.ids.grep_v(/\A[a-z]+(\.[A-Za-z0-9-]+){2,3}\z/)
      expect(bad).to be_empty
    end

    it "cites a known specification section on every conformance requirement" do
      missing = catalog.requirements.reject(&:abstract?).select do |req|
        cite = req.citation
        cite.nil? || cite.section.empty? || cite.title.empty? || cite.specification.version.empty?
      end
      expect(missing.map(&:id)).to be_empty
    end

    it "gives informational findings no normative citation" do
      expect(catalog.informational.filter_map(&:citation)).to be_empty
      expect(catalog.informational.map(&:severity).uniq).to eq(["info"])
    end

    it "returns frozen typed data and raises on an unknown ID" do
      req = catalog.fetch("png.gAMA.single-instance")
      expect(req).to be_frozen
      expect(req.citation.to_h).to include(section: "5.6", title: "Chunk ordering")
      expect { catalog.fetch("png.nope.nope") }
        .to raise_error(described_class::UnknownIdError)
    end
  end

  describe "validation" do
    it "rejects a duplicate requirement ID" do
      yaml = File.read(described_class::DEFAULT_PATH)
      id = "png.gAMA.single-instance:"
      dup = yaml.sub(/^  #{Regexp.escape(id)}\n(?:    .*\n)+/) { |entry| entry + entry }
      expect(dup).not_to eq(yaml)
      expect { load_document(dup) }.to raise_error(described_class::DuplicateIdError)
    end

    it "rejects an ID repeated across the requirement and informational sections" do
      data["informational"]["png.gAMA.single-instance"] =
        Marshal.load(Marshal.dump(data["informational"].values.first))
      expect { load_document(data) }.to raise_error(described_class::DuplicateIdError)
    end

    it "rejects a missing citation" do
      data["requirements"]["png.gAMA.single-instance"].delete("citation")
      expect { load_document(data) }
        .to raise_error(described_class::InvalidEntryError, /missing citation/)
    end

    it "rejects a citation to an unknown specification" do
      data["requirements"]["png.gAMA.single-instance"]["citation"]["specification"] = "nope"
      expect { load_document(data) }
        .to raise_error(described_class::InvalidEntryError, /unknown specification/)
    end

    %w[format kind severity].each do |field|
      it "rejects an unknown #{field}" do
        data["requirements"]["png.gAMA.single-instance"][field] = "bogus"
        expect { load_document(data) }
          .to raise_error(described_class::InvalidEntryError, /unknown #{field}/)
      end
    end

    it "rejects a citation on an informational finding" do
      id, entry = data["informational"].first
      entry["citation"] = { "specification" => "iso15948", "section" => "1", "title" => "x" }
      data["informational"][id] = entry
      expect { load_document(data) }
        .to raise_error(described_class::InvalidEntryError, /no citation/)
    end

    it "rejects an entry with no emitters" do
      data["requirements"]["png.gAMA.single-instance"]["emitters"] = []
      expect { load_document(data) }
        .to raise_error(described_class::InvalidEntryError, /missing emitters/)
    end
  end

  describe "emitter inventory" do
    it "covers all 47 registered validators: 28 PNG/APNG and 19 MNG/JNG" do
      files = inventory.registered_validator_files
      expect(files.size).to eq(47)
      expect(files.count { |f| f.match?(%r{/(critical|ancillary|apng)/}) }).to eq(28)
      expect(files.count { |f| f.match?(%r{/(mng|jng)/}) }).to eq(19)
    end

    it "gives every registered validator at least one cataloged emitter" do
      cataloged = catalog.flat_map { |r| r.emitters.map(&:file) }.uniq
      expect(inventory.registered_validator_files - cataloged).to be_empty
    end

    it "assigns every emitter site exactly one catalog entry" do
      expect(sites).not_to be_empty
      expect(uncovered_sites(catalog, sites)).to be_empty
    end

    it "leaves no catalog emitter without a matching source site" do
      found = sites.map { |s| [s.file, s.call] }.uniq
      stale = catalog.flat_map { |r| r.emitters.map { |e| [r.id, e.file, e.call] } }
        .reject { |_, file, call| found.include?([file, call]) }
      expect(stale).to be_empty
    end

    it "fails when a new emitter lacks a catalog ID" do
      extra = PngConform::Spec::EmitterInventory::Site.new(
        file: "validators/ancillary/gama_validator.rb", line: 1,
        call: 'add_error("a brand new gAMA rule")'
      )
      expect(uncovered_sites(catalog, sites + [extra])).to eq([[extra.file, extra.call]])
    end

    it "fails when a cataloged requirement is removed" do
      data["requirements"].delete("png.gAMA.single-instance")
      reduced = load_document(data)
      expect(uncovered_sites(reduced, sites).map(&:last))
        .to eq(['add_error("duplicate gAMA chunk")'])
    end

    it "agrees with the call each entry's severity is reported through" do
      expected = { "add_error" => "error", "add_warning" => "warning", "add_info" => "info",
                   "check_length" => "error", "check_range" => "error", "check_enum" => "error",
                   "check_crc" => "error", "error_result" => "error",
                   "warning_result" => "warning", "success_result" => "info" }
      mismatches = catalog.flat_map do |req|
        req.emitters.filter_map do |e|
          method = e.call[/\A\w+/]
          want = expected[method]
          next if want.nil? || e.call.include?("severity: :") || e.call.start_with?("add_error(chunk_type")

          [req.id, e.call] unless want == req.severity
        end
      end
      expect(mismatches).to be_empty
    end

    it "assigns each direct context finding the severity it is added with" do
      direct = catalog.flat_map do |req|
        req.emitters.select { |e| e.call.include?("severity: :") }.map { |e| [req.id, e.call] }
      end
      expect(direct.size).to be >= 6
      direct.each do |id, call|
        expect(call).to include("severity: :#{catalog.fetch(id).severity}")
      end
    end
  end

  describe "common helper findings" do
    let(:helper_sites) do
      sites.select { |s| s.file.start_with?("validators/") && s.call.match?(/\Acheck_(length|range|enum|crc)/) }
    end

    it "binds shared helper IDs only to BaseValidator itself" do
      shared = catalog.select(&:abstract?)
      expect(shared.map(&:id)).to contain_exactly("all.helper.crc", "all.helper.enum", "all.helper.length", "all.helper.range")
      expect(shared.flat_map { |r| r.emitters.map(&:file) }.uniq).to eq(["validators/base_validator.rb"])
      expect(catalog.reject(&:abstract?).flat_map { |r| r.emitters.map(&:file) })
        .not_to include("validators/base_validator.rb")
    end

    it "gives every helper call in a validator its own requirement, not a generic one" do
      by_id = helper_sites.map do |s|
        catalog.find { |r| r.emitters.any? { |e| e.file == s.file && e.call == s.call } }
      end
      expect(by_id).to all(satisfy { |r| r && !r.abstract? })
      crc = by_id.select { |r| r.id.end_with?(".crc") }
      expect(crc.map(&:id).uniq.size).to eq(crc.size)
      expect(crc.size).to be >= 40
      expect(by_id.map(&:id).grep(/\Aall\.helper\./)).to be_empty
    end

    it "keeps validators of different chunks on different length IDs" do
      lengths = catalog.select { |r| r.kind == "length" && r.id.end_with?(".length") }.map(&:id)
      expect(lengths).to include("png.IHDR.length", "png.tIME.length", "mng.MEND.length", "jng.JHDR.length")
    end
  end

  describe "profile policy findings" do
    it "separates chunk-level from file-level profile findings" do
      expected = {
        "profile.chunk.unknown-profile" => "error",
        "profile.chunk.prohibited" => "error",
        "profile.chunk.undefined" => "warning",
        "profile.file.prohibited-present" => "error",
        "profile.file.required-missing" => "error",
      }
      expected.each do |id, severity|
        req = catalog.fetch(id)
        expect(req).to have_attributes(kind: "policy", severity: severity)
        expect(req.citation.specification.key).to eq("profile")
        expect(req.citation.specification.version).not_to be_empty
        expect(req.emitters.map(&:file)).to eq(["services/profile_manager.rb"])
      end
      expect(catalog.fetch("profile.chunk.prohibited").emitters.first.call)
        .to include("prohibited in")
      expect(catalog.fetch("profile.file.prohibited-present").emitters.first.call)
        .to include("Prohibited chunk present")
    end

    it "catalogs profile success results as informational" do
      expect(catalog.fetch("info.profile.chunk.required-present")).to be_informational
      expect(catalog.fetch("info.profile.chunk.optional-present")).to be_informational
    end
  end

  describe "format citations" do
    def spec_keys(format)
      catalog.requirements.select { |r| r.format == format && r.citation }.map { |r| r.citation.specification.key }.uniq
    end

    let(:formats_with_dirs) { %w[apng mng jng] }

    it "cites the specification that governs each format" do
      # CRC integrity is defined once, by the PNG chunk layout all formats share.
      expect(spec_keys("apng")).to include("apng")
      expect(spec_keys("apng") - %w[apng iso15948]).to be_empty
      expect(spec_keys("jng")).to include("jng")
      expect(spec_keys("jng") - %w[jng iso15948]).to be_empty
      expect(spec_keys("mng")).to include("mng")
      expect(spec_keys("mng") - %w[mng iso15948]).to be_empty
      expect(spec_keys("png") - %w[iso15948 png3 pngext apple_idot profile]).to be_empty
    end

    it "derives each entry's format from the directory of its validator" do
      catalog.requirements.each do |req|
        files = req.emitters.map(&:file)
        formats_with_dirs.each do |dir|
          next unless files.all? { |f| f.start_with?("validators/#{dir}/") }

          expect(req.format).to eq(dir)
        end
      end
    end
  end

  describe "non-registry sources" do
    def run_ruby(code)
      Open3.capture3(RbConfig.ruby, "-I", File.join(root, "lib"), "-e", code, chdir: root)
    end

    let(:exclusions) { catalog.exclusions }

    it "classifies the four named sources with evidence" do
      expect(exclusions.keys).to include("pipelines", "zlib_validator", "streaming_idat_validator",
                                         "validation_service_helpers")
      exclusions.each_value do |ex|
        expect(ex.evidence).not_to be_empty
        expect(ex.rationale).not_to be_empty
        ex.paths.each { |path| expect(File.exist?(File.join(inventory::LIB_ROOT, path))).to be(true) }
      end
    end

    it "keeps excluded files out of the emitter inventory" do
      scanned = inventory.sources.keys
      excluded = exclusions.values.flat_map(&:paths)
      expect(excluded.select { |path| scanned.include?(path) || scanned.any? { |s| s.start_with?(path) } }).to be_empty
    end

    it "keeps dormant constants undefined after loading the library and every registered validator" do
      dormant = exclusions.values.select { |ex| ex.classification == "dormant" }
      constants = dormant.flat_map(&:constants)
      expect(constants.size).to eq(3)
      code = <<~RUBY
        require "png_conform"
        PngConform::Validators::ChunkRegistry::VALIDATOR_PATHS.each_key do |type|
          PngConform::Validators::ChunkRegistry.validator_for(type)
        end
        defined_now = #{constants.inspect}.select { |name| Object.const_defined?(name) }
        abort("loaded: \#{defined_now.join(', ')}") unless defined_now.empty?
      RUBY
      _out, err, status = run_ruby(code)
      expect(status).to be_success, err
    end

    it "finds no reference to dormant sources outside their own files" do
      dormant = exclusions.values.select { |ex| ex.classification == "dormant" }
      own = dormant.flat_map { |ex| ex.paths.map { |p| File.join(inventory::LIB_ROOT, p) } }
      scan_roots = %w[lib spec exe bin examples benchmarks docs README.adoc Rakefile].map { |p| File.join(root, p) }
      this_spec = File.expand_path(__FILE__)
      files = scan_roots.flat_map { |p| File.directory?(p) ? Dir.glob(File.join(p, "**", "*")) : [p] }
        .select { |f| File.file?(f) }
        .reject { |f| own.any? { |o| f.start_with?(o) } || f == this_spec }
      dormant.each do |ex|
        pattern = Regexp.new(ex.reference_pattern)
        hits = files.select { |f| text_of(f).match?(pattern) }
        expect(hits).to eq([]), "#{ex.key} is referenced from #{hits.join(', ')}"
      end
    end

    it "documents ValidationService as a facade over the cataloged orchestrator" do
      ex = exclusions.fetch("validation_service_helpers")
      service = PngConform::Services::ValidationService
      expect(service.private_instance_methods(false)).to include(*ex.private_helpers.map(&:to_sym))
      source = File.read(File.join(inventory::LIB_ROOT, "services/validation_service.rb"))
      expect(source).to include("ValidationOrchestrator.validate_file(filepath, options)")
      expect(source).to include("@orchestrator.validate")
      ex.uncalled_helpers.each do |name|
        references = Dir.glob(File.join(root, "{lib,spec,docs}", "**", "*")).select { |f| File.file?(f) && f != File.expand_path(__FILE__) }
          .sum { |f| text_of(f).scan(/\b#{name}\b/).size }
        expect(references).to eq(1)
      end
      expect(source.scan(/\badd_(?:error|warning|info)\(msg\)/).size).to eq(3)
    end

    it "catalogs the active orchestrator and chunk processor findings the facade delegates to" do
      ids = catalog.select { |r| r.emitters.any? { |e| e.file == "services/validation_orchestrator.rb" } }.map(&:id)
      expect(ids).to contain_exactly("png.signature.invalid", "png.IHDR.missing", "png.IEND.missing", "png.IDAT.missing")
      processor = catalog.select { |r| r.emitters.any? { |e| e.file == "services/chunk_processor.rb" } }.map(&:id)
      expect(processor).to contain_exactly("png.chunk.unknown-critical", "info.png.chunk.unknown-ancillary")
    end
  end
end
