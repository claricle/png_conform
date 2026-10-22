# Issue #9 — Lens-family structured diagnostics

Planning baseline: `origin/main` at `653abae0d16d9533a37a5d5eca40896d3b307993`.

## Problem

`png_conform` currently carries diagnostics through several incompatible representations. Validators add hashes to `ValidationContext`; `ResultBuilder#add_context_messages` then forwards only each message into `ValidationResult`; and `FileAnalysis#to_h` emits a small legacy subset. That path loses chunk offsets and error types before JSON/YAML reporting, while human reporters format the reduced model independently.

Issue #9 asks for the lens-family diagnostic contract: stable identity/kind, severity, a format-native location, spec or profile citation, and machine and human renderings derived from one model. The change must cover every in-scope conformance failure and pin the resulting JSON for the fixture corpus.

The shared schema is not yet a landed dependency. `svg_conform` issue #100 is responsible for defining it in the new zero-dependency `claricle/lens_core` gem (`LensCore`), while the EMF conformance work in issue #37 is on an unmerged feature branch. Existing SVG API and CLI reports also differ and lose fields in adaptation, so neither current SVG shape should be copied as the canonical contract.

## Scope

- Consume `LensCore` from the `claricle/lens_core` git branch published by `claricle/svg_conform#100`, then move to its released dependency when v1 freezes. Do not vendor the contract.
- Keep a PNG adapter around the shared model so byte offset, chunk type/index, field name, expected value, and actual value can be represented without forcing SVG line/column semantics.
- Give every active or documented direct-use conformance emitter a stable requirement ID, kind, default severity, and authoritative specification/profile citation; classify reachability before including non-registry source files.
- Carry the same diagnostic object through validation context, result building, the Ruby API, JSON/YAML, and text reporters without dropping fields.
- Map all 47 registered format validators—28 PNG/APNG and 19 MNG/JNG—plus shared `BaseValidator` behavior and other proven active/public emitters. Cite ISO/IEC 15948 for PNG plus the MNG 1.0 and JNG specification sections for MNG/JNG findings.
- Make the active reader/orchestrator path format-aware: recognize PNG, MNG, and JNG signatures, apply each format's own top-level header/data/terminator rules, and prove complete valid and invalid files without cross-format false findings.
- Pin deterministic structured JSON for all 180 existing PNG fixtures and a small, licensed MNG/JNG fixture set, with a reviewable, check-only regeneration workflow.
- Document the public Ruby and CLI schemas, compatibility behavior, location semantics, and golden update procedure.

## Exclusions

- Defining, copying, or vendoring a competing family-wide contract inside this repository.
- Implementing SVG, EMF, or PostScript conformance behavior in this repository.
- Converting CLI invocation, missing-file, dependency, or unexpected process failures into conformance findings; those remain operational errors unless the shared contract explicitly says otherwise.
- Changing rule semantics beyond correcting the active path's PNG-only format dispatch and top-level PNG/MNG/JNG sequence checks; auto-remediation behavior, profile policy, and pngcheck-compatible exit status otherwise remain unchanged.
- Wiring or migrating dormant code merely because it contains emitter-like methods. Card 02 classifies `lib/png_conform/pipelines/`, `Services::ZlibValidator`, `Validators::StreamingIdatValidator`, and the legacy private emitter helpers in `ValidationService`; sources with no registry, require/call, or documented direct-use public contract stay out of the migration.

## Intended end state

- A single immutable diagnostic value is created at the rule boundary and survives unchanged to all report formats.
- Its serialized shape matches the landed, versioned lens-family contract and includes stable requirement identity, kind, severity, message, structured citation, and an extensible location containing PNG-native context.
- Human output is rendered from that value; it does not reconstruct meaning from message text.
- Public report shapes add the canonical diagnostics while compatibility aliases preserve the legacy Ruby/JSON surface for one documented transition.
- A catalog completeness check covers every active emitter, and corpus goldens make schema, ordering, optional-field, filename, and timestamp changes review-visible.

## Cross-repository prerequisites

1. **Blocking contract prerequisite — `svg_conform#100`:** a reviewed commit must publish the zero-dependency `claricle/lens_core` gem on a consumable git branch, including field names, primitive/optional value rules, deterministic ordering, human-rendering boundary, extensible location/citation representation, and schema version. The png_conform dependency remains pinned to that branch until the LensCore v1 contract freezes; a released v1 is not required to begin this issue.
2. **Non-blocking family-parity check — `emf#37`:** recheck the EMF integration once it consumes LensCore and demonstrate the same common fields and serialization rules. EMF's current feature branch is useful evidence, but it neither defines nor supplies PNG's runtime contract.
3. PNG implementation may inventory all format rules and citations while the LensCore branch is pending, but cards 01, 03a–03c, 04, and 05 cannot be accepted against an assumed schema.

## Ordering and parallelism

1. Start card 02’s complete PNG/APNG/MNG/JNG inventory immediately.
2. Complete card 01 after `svg_conform#100` satisfies the blocking prerequisite.
3. Cards 03a and 03b depend on cards 01 and 02, and may run in parallel by validator family.
4. Card 03c follows the shared diagnostic APIs and both emitter conversions; it owns the reader/orchestrator format dispatch and full-file PNG/MNG/JNG integration proofs.
5. Card 04 follows cards 03a–03c so additive compatibility assertions exercise the final cross-format objects.
6. Card 05 may source and license the small MNG/JNG fixture set early, but golden generation follows card 04; perform its single reviewed regeneration only after the schema, format dispatch, and rendering policy are frozen.

## Effort

| Card | Work | Estimate |
| --- | --- | ---: |
| 01 | Shared contract and PNG adapter | 1–2 engineer-days |
| 02 | Requirement catalog and citation inventory | 1–2 engineer-days |
| 03a | PNG/APNG and service emitters | 2–3 engineer-days |
| 03b | MNG/JNG emitters | 1.5–2.5 engineer-days |
| 03c | Format-aware readers, orchestration, and full-file integration | 1.5–2.5 engineer-days |
| 04 | Ruby API and report migration | 1.5–2.5 engineer-days |
| 05 | Licensed cross-format corpus, goldens, documentation, and release gate | 1.5–3 engineer-days |

The required PNG/APNG/MNG/JNG scope totals **10–17.5 engineer-days**. The total excludes the external wait for the LensCore branch and assumes authoritative specification text and suitable redistributable MNG/JNG samples are available to the implementer.

## Project decisions

1. `claricle/lens_core` is the sole shared-contract source. png_conform consumes its git branch until v1 freezes and never vendors a local copy.
2. PNG, APNG, MNG, and JNG are all required. All 47 registered format validators are mapped, the active validation path dispatches their distinct signatures and top-level rules, and the golden corpus gains a small licensed MNG/JNG set alongside the 180 PNG fixtures.
3. Public report changes are additive. Compatibility aliases preserve the legacy surface for one documented transition; this issue does not perform a breaking replacement.

## Planning evidence

- `lib/png_conform/validators/base_validator.rb` creates context hashes with message/severity/chunk/offset.
- `lib/png_conform/services/result_builder.rb` drops all fields except message when building results.
- `lib/png_conform/models/validation_error.rb` lacks canonical requirement, citation, and location values.
- `lib/png_conform/models/file_analysis.rb` defines the current machine representation; `lib/png_conform/reporters/json_reporter.rb` serializes it directly.
- `ChunkRegistry::VALIDATOR_PATHS` has 47 registered format validators: 28 PNG/APNG and 19 MNG/JNG. `BaseValidator` is shared infrastructure outside that count; `StreamingIdatValidator` is not registered.
- `lib/png_conform/services/profile_manager.rb` is loaded by the public library and directly exposes profile validation. `validate_chunk_against_profile` emits unknown-profile and prohibited-chunk errors plus undefined-chunk warnings; `validate_file_against_profile` emits prohibited-present and missing-required errors. Those existing semantics must enter the canonical model while their public result keys remain available during the compatibility transition.
- `ValidationOrchestrator` currently accepts only the PNG signature and unconditionally requires `IHDR`, `IEND`, and `IDAT`. `StreamingReader` likewise recognizes only the PNG signature and stops only at `IEND`; format-specific BinData models establish MNG's `MHDR`/`MEND` envelope and JNG's `JHDR`/`JDAT`/`IEND` envelope.
- The source tree has 317 candidate diagnostic-emission call sites before reachability filtering, 49 registered-validator spec files, 180 PNG fixtures, no MNG/JNG fixtures, and no diagnostic JSON goldens.
- `FileAnalysis#to_h` currently emits `severity` and `message` for each error plus optional `chunk_type`, `expected`, and `actual`; `chunk_offset` and `error_type` exist as Ruby readers but are not current JSON keys.
