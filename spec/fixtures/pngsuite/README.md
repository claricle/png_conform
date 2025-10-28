# PngSuite Test Fixtures

This directory contains test images from Willem van Schaik's PngSuite, the industry-standard PNG test suite.

## Source

- **Source**: http://www.libpng.org/pub/png/pngsuite.html
- **Author**: Willem van Schaik
- **Copyright**: © 1995-1998 (and 2011) Willem van Schaik
- **License**: Public domain / Free for testing purposes

## Directory Structure

```
spec/fixtures/pngsuite/
├── valid/          # Valid PNG files covering different formats
├── invalid/        # Invalid/corrupted PNG files for error testing
└── edge_cases/     # Edge cases (1x1, interlaced, alpha, etc.)
```

## Downloaded Files

### Valid PNG Files (`valid/`)

- `basn0g01.png` - 1-bit grayscale (black & white)
- `basn0g08.png` - 8-bit grayscale (256 levels)
- `basn2c08.png` - 8-bit RGB truecolor
- `basn3p08.png` - 8-bit paletted (256 colors)

### Invalid PNG Files (`invalid/`)

- `x00n0g01.png` - Empty 0x0 grayscale file
- `xcrn0g04.png` - Corrupted with added CR bytes
- `xlfn0g04.png` - Corrupted CR→LF conversion, NULs removed

### Edge Cases (`edge_cases/`)

- `s01n3p01.png` - 1x1 pixel paletted file
- `s09n3p02.png` - 9x9 pixel paletted file
- `basi0g01.png` - 1-bit grayscale, interlaced (Adam7)
- `basn6a16.png` - 16-bit RGBA with alpha channel

## Complete PngSuite

To download the complete 91-image suite:

```bash
# Download entire suite (requires wget or curl with proper site access)
# Visit: http://www.schaik.com/pngsuite2011/pngsuite.html
```

## Naming Convention

PngSuite uses a systematic naming convention:

```
[prefix][interlace][color_type][bit_depth].png

Prefixes:
  bas - basic format
  s   - size test (followed by dimension)
  bg  - background
  tp  - transparency
  g   - gamma
  f   - filter
  cs  - significant bits
  cd  - physical dimensions
  cc  - chromaticity
  cm  - modification time
  ct  - text
  ch  - histogram
  pp  - palette
  ps  - suggested palette
  oi  - chunk ordering
  z   - compression level
  x   - corrupted/invalid

Interlace:
  n - non-interlaced
  i - interlaced (Adam7)

Color types:
  0g - grayscale
  2c - RGB color
  3p - paletted
  4a - grayscale + alpha
  6a - RGBA

Bit depth:
  01, 02, 04, 08, 16
```

## Usage in Tests

These fixtures are used to test:

1. **Binary parsing** - Correct reading of PNG structure
2. **Validation** - Proper error detection
3. **Output formatting** - Matching pngcheck's output
4. **Edge cases** - Handling unusual but valid files
5. **Error handling** - Graceful handling of corrupt files

## Adding More Fixtures

To add more test files:

```bash
cd spec/fixtures/pngsuite/{category}
curl -O http://www.libpng.org/pub/png/PngSuite/{filename}.png
```

Where `{category}` is one of: `valid`, `invalid`, `edge_cases`
