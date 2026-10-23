# 04 — Unify Ruby, JSON, YAML, and text reports

## Purpose

Make the canonical diagnostic the only source for public machine and human output while adding it to existing report shapes with compatibility aliases for one documented transition.

## Work

- Update `PngConform::Models::ValidationResult` and `FileAnalysis#to_h` to expose the shared diagnostic projection without rebuilding or discarding fields. Add the upstream schema version at the contract-defined report location.
- Update `JsonReporter` and `YamlReporter` to serialize that projection with stable diagnostic ordering and explicit absent-field policy. Normalize or omit volatile timestamps and host-specific paths as prescribed by the shared contract.
- Update `TextReporter`, `SummaryReporter`, `VerboseReporter`, `VeryVerboseReporter`, `QuietReporter`, and `ColorReporter` to call the diagnostic’s human renderer, with reporter-specific filtering/color outside the diagnostic model.
- Preserve check-command exit behavior: error-severity diagnostics make a result invalid; warnings/info do not. Keep missing-file and unexpected-process failures on the operational error path.
- Preserve the existing Ruby readers `severity`, `message`, `chunk_type`, `chunk_offset`, `error_type`, `expected`, and `actual` as compatibility aliases for one documented transition.
- Preserve the JSON fields actually emitted by `FileAnalysis#to_h` today: `severity` and `message`, with optional `chunk_type`, `expected`, and `actual`. Add the canonical diagnostic projection without removing or repurposing those fields. Treat any flattened `chunk_offset` or `error_type` JSON fields as deliberate new additive projections—not legacy keys—and document and pin their exact placement if they are introduced in addition to the canonical location/kind fields.
- Update `README.adoc`, `docs/CLI_OPTIONS.adoc`, and `docs/ARCHITECTURE.adoc` with the schema/version, a structured example, location/citation semantics, and migration notes.

## Dependencies

- Cards 01 and 03a–03c.

## Done when

- Ruby API, JSON, and YAML expose the same diagnostic identity, severity, kind, citation, location, message, and context with JSON-safe values.
- Focused model/reporter specs preserve every existing Ruby reader and the current five-field legacy JSON projection, and explicitly assert any newly added flattened `chunk_offset` or `error_type` projection as additive.
- Text-family reporters render from the same object and preserve their documented filtering/color responsibilities.
- Error/warning validity and CLI exit status remain covered, including operational failures that are not conformance diagnostics.
- The documented examples match executable reporter output, identify every compatibility alias, define the transition boundary, and state the schema version.

```bash
bundle exec rspec spec/png_conform/models/validation_error_spec.rb \
  spec/png_conform/models/validation_result_spec.rb \
  spec/png_conform/models/file_analysis_spec.rb \
  spec/png_conform/reporters \
  spec/png_conform/commands/check_command_spec.rb
```

## Status

State: done
PR: https://github.com/claricle/png_conform/pull/19
