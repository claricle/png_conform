# 03a — Convert PNG, APNG, and service emitters

## Purpose

Create the canonical diagnostic once at each active PNG/APNG rule boundary and carry it without metadata loss through the validation pipeline.

## Work

- Change `ValidationContext` in `lib/png_conform/validators/base_validator.rb` to collect diagnostic values instead of ad hoc hashes. Require a catalog ID at every conformance-diagnostic boundary, explicitly including informational findings; pass dynamic message data, PNG location, and expected/actual context separately.
- Update the 28 registered non-MNG/JNG validators under `lib/png_conform/validators/critical/`, `ancillary/`, and `apng/` to emit the cataloged requirements from card 02. Convert shared `BaseValidator` behavior separately; it is infrastructure, not a 29th registered validator.
- Convert the direct active unknown-critical findings in `lib/png_conform/services/chunk_processor.rb`, plus any other non-registry emitter that card 02 proves has a documented, tested direct-use public contract. Card 03c exclusively owns `ValidationOrchestrator` signature, missing-chunk, and top-level ordering findings so format dispatch is changed and tested as one unit.
- Migrate the active profile-policy emitter in `lib/png_conform/services/profile_manager.rb` without changing its split responsibilities. `validate_chunk_against_profile` must construct canonical diagnostics for an unknown profile, a prohibited chunk, and a chunk undefined by the profile; `validate_file_against_profile` must construct them for prohibited-present and missing-required chunks. Preserve the former method's existing `status`/`message` keys and the latter's `valid`/`errors`/`warnings` keys as compatibility projections for the documented transition; no profile finding may remain string-only internally.
- Keep `Services::ZlibValidator`, `Validators::StreamingIdatValidator`, and the legacy private emitter helpers in `ValidationService` out of the migration under the current source evidence: the first two have no require/call path, the streaming validator is absent from the registry, and the helper emitters are unused. Do not make them reachable as part of this issue. If card 02 finds an existing documented direct-use contract, add that source to the explicit active inventory and add a focused spec before converting it.
- Refactor `ResultBuilder#add_context_messages` in `lib/png_conform/services/result_builder.rb` to append each diagnostic intact. Remove severity-specific reconstruction that currently retains only `e[:message]`.
- Follow card 02’s reachability finding for `lib/png_conform/pipelines/`: adapt an emitter only if an existing public/reachable path is proven; otherwise record the directory as outside the active issue path. Do not create a second diagnostic pipeline by making dormant code reachable.
- Extend existing validator and profile-manager specs to assert IDs, citations, severity, and applicable absolute byte/chunk locations in addition to message text. In `spec/png_conform/services/profile_manager_spec.rb`, add structured assertions for unknown-profile, prohibited-chunk, and undefined-chunk results from `validate_chunk_against_profile`, plus prohibited-present and missing-required results from `validate_file_against_profile`; keep the existing success examples as preservation checks. Card 03c owns orchestrator and full-file integration assertions.
- Together with card 03b, make `spec/png_conform/diagnostics/emitter_coverage_spec.rb` enumerate all 47 registered validators so the agreed inventory is explicit and regression-visible.

## Dependencies

- Cards 01 and 02.
- Card 03b runs in parallel after the shared context/catalog APIs are merged; both emitter cards feed card 03c and are required before card 04.

## Done when

- All active PNG/APNG and shared-service errors, warnings, and conformance-information messages across the 28 registered non-MNG/JNG validators originate as canonical diagnostics with catalog IDs and citations.
- `ValidationContext` to `ResultBuilder` preserves diagnostic identity, location, expected/actual context, and severity exactly.
- CRC, unknown-critical, registered compressed-payload, and representative critical/ancillary/APNG failures each have focused structured assertions; card 03c separately proves signature and top-level sequence findings.
- `ProfileManager.validate_chunk_against_profile` has structured assertions for unknown-profile and prohibited-chunk errors plus an undefined-chunk warning; `ProfileManager.validate_file_against_profile` has structured prohibited-present and missing-required-chunk assertions. Every case proves stable ID, policy citation, severity, message, and the applicable profile/chunk context while preserving current compatibility keys.
- Dormant non-registry classes and unused `ValidationService` helper emitters are neither wired into production nor counted as migrated unless their pre-existing direct-use public contract is documented and covered by a focused spec.
- No active PNG/APNG conformance emitter bypasses the cataloged diagnostic constructor.

```bash
bundle exec rspec spec/png_conform/diagnostics/emitter_coverage_spec.rb \
  spec/png_conform/validators/base_validator_spec.rb \
  spec/png_conform/validators/critical \
  spec/png_conform/validators/ancillary \
  spec/png_conform/validators/apng \
  spec/png_conform/services/profile_manager_spec.rb
```

## Status

State: done
PR: https://github.com/claricle/png_conform/pull/17
