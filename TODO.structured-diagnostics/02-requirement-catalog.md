# 02 — Catalog every rule and citation

## Purpose

Replace message text as the implicit rule identity with a complete, reviewable registry across PNG, APNG, MNG, and JNG. This card can begin while the upstream schema is pending.

## Work

- Add `config/diagnostics.yml`, keyed by stable requirement ID, with format, kind, default severity, specification/profile name and version, and exact section/clause citation. Keep messages/templates in the catalog only if the shared contract standardizes them there.
- Add `lib/png_conform/diagnostics/catalog.rb` to load and validate the registry, reject duplicate/unknown IDs, and return typed data for diagnostic construction.
- Inventory the 47 validators registered in `ChunkRegistry::VALIDATOR_PATHS`—28 PNG/APNG and 19 MNG/JNG—then separately inventory shared findings from `lib/png_conform/validators/base_validator.rb`, direct findings in `lib/png_conform/services/validation_orchestrator.rb` and `chunk_processor.rb`, and the public profile findings from `ProfileManager.validate_chunk_against_profile` and `ProfileManager.validate_file_against_profile` in `lib/png_conform/services/profile_manager.rb`. Inventory any other emitter only when it is proven active or covered by a documented direct-use public contract. Include active informational diagnostics in the one-model migration even though they are not failures.
- Trace registry membership, `require` edges, call sites, public documentation, and focused direct-use tests for non-registry sources. Record an explicit include/exclude rationale for `lib/png_conform/pipelines/`, `Services::ZlibValidator`, `Validators::StreamingIdatValidator`, and the legacy private emitter helpers in `ValidationService`. Do not wire dormant classes into production or catalog unreachable helper methods just to expand coverage; a non-registry source enters scope only when a direct-use public contract is documented and tested.
- Assign citations from ISO/IEC 15948 (including the applicable edition), the APNG specification, and the MNG 1.0 and JNG specifications. Profile-only policy findings cite the profile ID/version rather than inventing a normative PNG clause.
- Add `spec/png_conform/diagnostics/catalog_spec.rb` to prove schema validity, unique IDs, known severities/kinds/formats, citation presence, and complete coverage of the explicit emitter inventory. The inventory must fail when a new emitter lacks a catalog ID.
- Document non-conformance informational messages separately; do not give success/progress messages fictitious normative citations.

## Dependencies

- Access to the authoritative editions used for clause-level review.
- The final serializer keys wait on card 01, but stable IDs and source citations do not.

## Done when

- Every active error, warning, and conformance-information path across all 47 registered validators, shared `BaseValidator` behavior, and other proven active/public emitters has one stable catalog ID and an authoritative spec/profile citation appropriate to its format.
- The catalog distinguishes `ProfileManager.validate_chunk_against_profile` findings for an unknown profile, a prohibited chunk, and a chunk undefined by a profile from `validate_file_against_profile` findings for a prohibited-present chunk and a missing required chunk, with the applicable profile ID/version as the policy citation.
- Common helper findings remain distinguishable by violated requirement rather than collapsing to one generic length/range/CRC ID.
- Duplicate IDs, missing citations, unknown metadata values, and uncataloged emitters fail a focused completeness spec.
- The inventory records a source-backed reachability/public-contract classification for `lib/png_conform/pipelines/`, `Services::ZlibValidator`, `Validators::StreamingIdatValidator`, and the legacy `ValidationService` helper emitters so card 03a has explicit inclusion decisions and no speculative migration work.

```bash
bundle exec rspec spec/png_conform/diagnostics/catalog_spec.rb
```

## Status

State: done
PR: https://github.com/claricle/png_conform/pull/13
