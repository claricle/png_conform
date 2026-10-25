# 05 — Pin corpus JSON and the release gate

## Purpose

Make the one-time schema transition reviewable and ensure future rule/report changes cannot silently alter diagnostics across the fixture corpus.

## Work

- Add `script/regenerate_diagnostic_goldens` with explicit `--write` and non-mutating `--check` modes. Process fixtures in bytewise sorted repo-relative order and reject unknown options or a dirty/partial target set.
- Mirror all 180 PNG inputs under `spec/fixtures/diagnostics/pngsuite/` as canonical pretty JSON. Normalize input names to repo-relative paths and follow LensCore's timestamp/optional-field policy so repeated generation is byte-identical.
- Add a small redistributable fixture set under the proposed `spec/fixtures/mng/` and `spec/fixtures/jng/` paths, with source, license, and expected-validity metadata recorded beside the fixtures. Include representative valid and invalid MNG/JNG structures that exercise their format-specific citations.
- Mirror the MNG/JNG inputs under proposed `spec/fixtures/diagnostics/mng/` and `spec/fixtures/diagnostics/jng/` paths, and add proposed `spec/structured_diagnostics/corpus_spec.rb` to assert one-to-one cross-format input/golden coverage, parseability, schema version, deterministic ordering, and exact output equality. Include valid files with empty findings and invalid/edge files, using card 03c's format-aware full-file path rather than bypassing orchestration.
- Perform exactly one intentional `--write` regeneration after cards 01, 02, 03a–03c, and 04 have `State: done` and the shared schema, format dispatch, and rendering policy are frozen. Then review the complete artifact diff once as a dedicated transition step; subsequent CI uses `--check` and never rewrites files.
- Add the check to the existing Rake/CI path only after its runtime and memory usage are measured. Keep a targeted representative fixture subset for fast local development if the full corpus is too slow, but do not weaken the full CI acceptance gate.
- Document regeneration and review procedure in `CONTRIBUTING.md`; update fixture counts only through the coverage assertion, not a hand-maintained magic number.

## Dependencies

- Cards 01–04, including card 03c's full-file format dispatch, and a frozen shared schema/ordering policy.
- Suitable redistributable MNG/JNG samples and recorded license/provenance; the current checked-in corpus contains 180 PNG fixtures and no MNG/JNG fixtures.

## Done when

- Every checked-in PNG fixture and every newly licensed MNG/JNG fixture has exactly one deterministic structured JSON golden, including valid fixtures with no findings.
- The MNG/JNG fixture metadata records a redistribution-compatible license, source, format, and expected validity, and the set exercises both format-specific diagnostic citations.
- `--check` detects missing, extra, stale, reordered, schema-incompatible, or host-dependent golden output without writing files.
- The one-time transition regeneration is isolated for human review, and later CI proves no unreviewed drift.
- Contributor documentation explains targeted checks, full-corpus verification, and the controlled regeneration command.

```bash
bundle exec rspec spec/integration/png_validation_spec.rb \
  spec/integration/mng_validation_spec.rb \
  spec/integration/jng_validation_spec.rb
script/regenerate_diagnostic_goldens --check
bundle exec rspec spec/structured_diagnostics/corpus_spec.rb
bundle exec rubocop
```

## Status

State: done
PR: https://github.com/claricle/png_conform/pull/12
