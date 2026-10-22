# 03b — Convert MNG and JNG emitters

## Purpose

Apply the same contract to the other file formats that `png_conform` publicly advertises, using their own normative specifications rather than mislabeling their requirements as ISO/IEC 15948 rules.

## Work

- Update all 19 validators under `lib/png_conform/validators/mng/` and `lib/png_conform/validators/jng/` to require the stable IDs cataloged in card 02.
- Preserve MNG/JNG byte offsets, chunk type/index, field context, expected/actual values, severity, and format in the shared location/context projection.
- Extend the existing MNG/JNG validator specs with structured identity and citation assertions for representative length, field, sequence, and required-chunk failures.
- Add MNG/JNG emitter coverage to `spec/png_conform/diagnostics/emitter_coverage_spec.rb` so future rules cannot silently return to message-only errors.

## Dependencies

- Cards 01 and 02.
- Card 03a shares the context/catalog APIs and emitter-coverage spec; coordinate those files while converting the two required format families. Card 03c consumes both emitter cards and owns end-to-end format dispatch.

## Done when

- Every active MNG/JNG conformance error, warning, and information message across all 19 validators uses a stable catalog ID and the applicable MNG 1.0 or JNG specification section.
- Representative MNG and JNG diagnostics preserve structured format, byte/chunk location, severity, and rule identity through `ValidationResult`.
- The emitter completeness spec covers the MNG/JNG validator directories and fails on an uncataloged finding.

```bash
bundle exec rspec spec/png_conform/diagnostics/emitter_coverage_spec.rb \
  spec/png_conform/validators/mng \
  spec/png_conform/validators/jng
```

## Status

State: todo
PR: none
