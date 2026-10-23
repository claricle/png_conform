# 01 — Adopt the shared contract behind a PNG adapter

## Purpose

Bind `png_conform` to the zero-dependency `claricle/lens_core` gem defined by `svg_conform#100` without copying SVG-only coordinates or coupling validators to package internals. Preserve the existing `ValidationError` entry points as additive compatibility aliases while making the shared diagnostic the source of truth.

## Work

- Declare the `lens_core` runtime dependency in `png_conform.gemspec` and pin `claricle/lens_core` to the reviewed integration branch through `Gemfile`/`Gemfile.lock` until v1 freezes. Replace the git source with the released v1 constraint at freeze; do not publish png_conform while its installable dependency is unavailable.
- Require LensCore directly from the dependency. Do not create a vendored or locally reimplemented shared-contract module.
- Add `lib/png_conform/diagnostics/location.rb` for PNG-native location data: byte offset plus optional chunk type, chunk index, and field. Its shared projection must use only the extension/context mechanism defined upstream.
- Add `lib/png_conform/diagnostics/citation.rb` only if the upstream contract delegates citation construction to consumers; otherwise wrap the upstream value without changing its keys.
- Refactor `PngConform::Models::ValidationError` to own/delegate to the shared immutable diagnostic while retaining documented severity predicates, factories, legacy readers, and `#to_s` behavior as compatibility aliases for one documented transition.
- Add `spec/png_conform/diagnostics/shared_contract_spec.rb` to pin schema version, primitive types, optional-field policy, location projection, stable serialization, and human rendering. Extend `spec/png_conform/models/validation_error_spec.rb` for legacy compatibility.

## Dependencies

- Blocking: `svg_conform#100` publishes the versioned LensCore schema and a consumable `claricle/lens_core` git branch.
- Non-blocking parity evidence: once EMF #37 consumes LensCore, its contract tests serialize the same common fields. PNG-specific location context may differ.

## Done when

- The dependency points to one reviewed LensCore branch revision, and no second family schema or vendored copy is defined locally.
- A PNG diagnostic round-trips stable requirement identity, kind, severity, message, citation, and byte/chunk location using JSON-safe primitives.
- The same object produces machine and human representations, and changing a structured field changes both applicable representations without message parsing.
- Existing documented `ValidationError` readers and predicates remain available as compatibility aliases for the documented transition.

```bash
bundle exec rspec spec/png_conform/diagnostics/shared_contract_spec.rb \
  spec/png_conform/models/validation_error_spec.rb
```

## Status

State: done
PR: https://github.com/claricle/png_conform/pull/14
