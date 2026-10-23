# 03c — Make orchestration format-aware

## Purpose

Route complete PNG, MNG, and JNG files through their own signatures and top-level sequence requirements so valid non-PNG inputs do not receive false PNG diagnostics.

## Work

- Give the active reader/orchestrator path one exact signature-to-format dispatch table for PNG (`89 50 4e 47 0d 0a 1a 0a`), MNG (`8a 4d 4e 47 0d 0a 1a 0a`), and JNG (`8b 4a 4e 47 0d 0a 1a 0a`). Preserve the detected format in validation context/result construction; an unknown signature emits its own cataloged signature diagnostic and does not trigger an arbitrary format's required-chunk findings.
- Refactor `lib/png_conform/services/validation_orchestrator.rb` to dispatch top-level rules by detected format: PNG/APNG requires first `IHDR`, last `IEND`, and at least one `IDAT`; MNG requires first `MHDR` and last `MEND`; JNG requires first `JHDR`, last `IEND`, and at least one `JDAT`. Check actual first/last positions as well as presence, and emit the card 02 catalog IDs and format-specific citations through the canonical constructor.
- Make `lib/png_conform/readers/streaming_reader.rb` recognize all three signatures and stop at the detected format's outer terminator (`IEND` for PNG/JNG, `MEND` for MNG), rather than rejecting or truncating an otherwise valid MNG/JNG stream. Keep `FullLoadReader` behavior covered so path-based validation continues to parse all three generic chunk streams.
- Extend `spec/png_conform/services/validation_orchestrator_spec.rb` for each recognized and unknown signature, each format's missing/misplaced header and terminator, PNG's missing `IDAT`, JNG's missing `JDAT`, and the absence of irrelevant cross-format findings.
- Add proposed `spec/png_conform/readers/format_dispatch_spec.rb`, `spec/integration/mng_validation_spec.rb`, and `spec/integration/jng_validation_spec.rb`. Build minimal complete files with valid CRCs in the focused specs; prove the public full-file path accepts valid `MHDR`/`MEND` and `JHDR`/`JDAT`/`IEND` streams with an empty diagnostic set. Keep `spec/integration/png_validation_spec.rb` as the PNG behavior-preservation proof.

## Dependencies

- Cards 01, 02, 03a, and 03b. This card owns `ValidationOrchestrator` and the reader format-dispatch specs after the shared diagnostic constructor and format validators are available.
- Card 04 consumes the detected format and canonical top-level findings; card 05 consumes the full-file MNG/JNG integration path for goldens.

## Done when

- Exact PNG, MNG, and JNG signatures select the correct format, while an unknown signature yields a cataloged signature diagnostic without unrelated PNG/MNG/JNG missing-chunk findings.
- Valid minimal PNG, MNG, and JNG files pass through the public full-file validation path with no diagnostics and the correct reported format.
- Missing or misplaced PNG `IHDR`/`IEND`/`IDAT`, MNG `MHDR`/`MEND`, and JNG `JHDR`/`IEND`/`JDAT` produce only the applicable stable IDs, citations, severities, and chunk locations.
- Streaming validation recognizes all three signatures, reads through the applicable outer terminator, and does not stop at an embedded MNG `IEND` before `MEND`.

```bash
bundle exec rspec spec/png_conform/services/validation_orchestrator_spec.rb \
  spec/png_conform/readers/format_dispatch_spec.rb \
  spec/integration/png_validation_spec.rb \
  spec/integration/mng_validation_spec.rb \
  spec/integration/jng_validation_spec.rb
```

## Status

State: done
PR: https://github.com/claricle/png_conform/pull/18
