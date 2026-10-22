# Progress and handoff

## Current state

- Planning is complete against `origin/main` commit `653abae0d16d9533a37a5d5eca40896d3b307993`.
- No implementation has started; cards 01–05 are `todo`.
- `ChunkRegistry::VALIDATOR_PATHS` contains 47 registered validators: 28 PNG/APNG and 19 MNG/JNG. `BaseValidator` is shared infrastructure outside that count.
- The source tree contains 317 candidate emission call sites before reachability filtering, 49 registered-validator specs, 180 PNG fixtures, no MNG/JNG fixtures, and no diagnostic JSON goldens.
- Current source evidence shows no require/call path for `Services::ZlibValidator` or `Validators::StreamingIdatValidator`; the streaming validator is absent from the registry, and the legacy private `ValidationService` emitter helpers are unused. They are excluded unless card 02 documents and tests an existing direct-use public contract.
- `lib/png_conform/services/profile_manager.rb` is loaded by the public library. `validate_chunk_against_profile` emits unknown-profile and prohibited-chunk errors plus undefined-chunk warnings; `validate_file_against_profile` emits prohibited-present and missing-required errors. Card 03a explicitly migrates and tests that existing split.
- `ValidationOrchestrator` currently accepts only the PNG signature and always requires `IHDR`, `IEND`, and `IDAT`; `StreamingReader` also recognizes only PNG and stops only at `IEND`. Card 03c now owns exact PNG/MNG/JNG signature dispatch, format-specific outer sequence rules, reader termination, and full-file integration proofs.
- The active context-to-result path loses metadata in `ResultBuilder#add_context_messages`; current reporter tests mainly assert messages, counts, and parseable JSON.

## Next executable action

1. While `svg_conform#100` publishes LensCore, start card 02 across all 47 registered validators using ISO/IEC 15948, APNG, MNG 1.0, JNG, and profile citations as applicable. Include the two public `ProfileManager` validation methods in the active inventory, and record reachability/public-contract dispositions for every other non-registry emitter candidate before cataloging it.
2. In parallel, identify a small redistributable MNG/JNG fixture set and record its license/provenance for card 05 without generating goldens yet.
3. When #100 publishes the reviewed `claricle/lens_core` integration branch, execute card 01, run required cards 03a and 03b in parallel, then execute card 03c's format-aware integration before the additive report migration.

## Blockers

- `svg_conform#100` has not yet published the reviewed `claricle/lens_core` integration branch and canonical schema. This blocks contract integration and acceptance of serialized output, but not the rule/citation inventory or fixture licensing work.
- EMF #37 remains unmerged. Its current branch is non-blocking evidence for requirement IDs, citations, severity/kind, offsets, and deterministic reporting; LensCore, not EMF, supplies the runtime contract.

## Remaining gaps and risks

- Authoritative clause mapping has not been performed; 317 call sites include shared helpers and repeated rules, so call-site count is not the final unique requirement count.
- `lib/png_conform/pipelines/` appears separate from the active orchestrator path; card 02 must classify it with the same registry/require/call/public-contract evidence used for zlib, streaming IDAT, and legacy `ValidationService` helpers. Dormant sources remain excluded and must not be wired in to satisfy coverage.
- `FileAnalysis#to_h` currently emits only `severity`, `message`, and optional `chunk_type`, `expected`, and `actual` per error. `ValidationError#chunk_offset` and `#error_type` are Ruby compatibility readers, not existing JSON keys; card 04 must test those baselines separately.
- The current corpus has 180 PNG fixtures and no MNG/JNG samples. Card 05 must find a small representative set whose license permits redistribution and record its provenance before cross-format goldens can pass.
- The current public validation path cannot yet make valid MNG/JNG files diagnostic-free because it applies PNG signature and required-chunk rules. Card 03c is an internal prerequisite for card 05: completion is observable when the proposed full-file MNG/JNG integration specs pass with the correct reported format and empty findings for valid minimal streams.
- LensCore may include timestamps or other volatile metadata; card 01 must adopt its determinism rule before any goldens are generated.
- Full corpus and full suite commands were intentionally not run during planning. Use targeted specs during implementation, then the controlled card 05 corpus gate.

## Handoff evidence

- Current path: `ValidationService` → `ValidationOrchestrator` → `ValidationContext` → `ResultBuilder` → `FileAnalysis` → reporters.
- Primary seams: `lib/png_conform/validators/base_validator.rb`, `lib/png_conform/services/result_builder.rb`, `lib/png_conform/models/validation_error.rb`, and `lib/png_conform/models/file_analysis.rb`.
- Format-dispatch seam: `lib/png_conform/services/validation_orchestrator.rb` plus `lib/png_conform/readers/streaming_reader.rb`; source models define PNG as `IHDR`/`IDAT`/`IEND`, MNG as `MHDR`/`MEND`, and JNG as `JHDR`/`JDAT`/`IEND` at the outer level.
- Active profile-policy seam: `lib/png_conform/services/profile_manager.rb`; its focused proof is `spec/png_conform/services/profile_manager_spec.rb`, including failure and warning cases rather than only the successful profile examples in `spec/integration/png_validation_spec.rb`.
- Related work must be rechecked at execution time: `claricle/svg_conform#100` must publish the blocking LensCore branch; `claricle/emf#37` remains a non-blocking family-parity reference.
