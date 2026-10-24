# Progress and handoff

## Current state

- Cards 01–05 are `done`. The structured diagnostics format from claricle/png_conform#9 is adopted end to end.
- Reports are built on the shared LensCore contract, with the requirement catalog, format-aware orchestration (PNG/MNG/JNG) and canonical report output in place.
- The corpus has one golden per checked-in fixture under `spec/fixtures/diagnostics/{pngsuite,idot,mng,jng}/`. Each golden is `ValidationResult#to_lens_report(filename: ...).to_h`, with every emitted diagnostic kept and no timestamp.
- `script/regenerate_diagnostic_goldens` has `--write` and `--check` modes. `bundle exec rake diagnostics:check` runs `--check` and is part of the default `rake` task (spec, rubocop, check), so CI catches drift.
- `spec/structured_diagnostics/corpus_spec.rb` asserts one-to-one fixture/golden coverage and exact output equality.
- `CONTRIBUTING.md` documents targeted checks, full-corpus verification and the controlled `--write` regeneration and review steps.

## Next executable action

None for this effort. Regenerate goldens with `--write` only for an intended rule, report or schema change, review the full golden diff, then confirm with `bundle exec rake diagnostics:check`.

## Blockers

None.

## Remaining gaps and risks

- Dormant sources (`Services::ZlibValidator`, `Validators::StreamingIdatValidator`, `lib/png_conform/pipelines/`) remain excluded from the catalog unless a public contract is documented for them.
