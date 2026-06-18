# Changelog

## 0.1.1 - 2026-06-18

- Bump dependencies to latest majors: `file_picker` ^11.0.0,
  `geolocator` ^14.0.0, `geocoding` ^4.0.0, and
  `google_mlkit_text_recognition` ^0.15.0.
- Migrate to file_picker 11's static `FilePicker.pickFiles` API
  (replaces the removed `FilePicker.platform` accessor). No public
  API changes; behavior is unchanged.

## 0.1.0 - 2026-05-28

First feature-complete release of `address_verify`.

- Headless `AddressVerifyEngine` with the full pre-screening pipeline:
  validate -> OCR -> address/name match -> location cross-reference ->
  weighted signal fusion -> packaged result.
- `AddressVerifyConfig` exposes developer-defined document types, signal
  toggles, weights, OCR language, return mode, and theme.
- Confidence fusion re-normalizes over present signals only, with a
  per-signal `ConfidenceBreakdown` returned alongside every result.
- Pure-Dart `AddressMatcher` and `NameMatcher` with normalization,
  bidirectional abbreviation handling, Jaccard overlap, and critical-token
  scoring.
- File handling supports PDF, PNG, and JPG with size and format guards;
  PDFs are rasterized via `pdfx` (up to 3 pages when the first is sparse).
- Default OCR provider backed by `google_mlkit_text_recognition`; callers
  can inject their own via `OcrProvider`.
- Optional GPS country cross-reference via `geolocator` + `geocoding`,
  including a `mockedLocation` advisory flag.
- Themeable `AddressVerifyWidget` covering doc-type select, upload, address
  form, and submit, plus a runnable `example/` app wiring every option.
- Honest-naming gate, golden matcher cases (including Nigerian/African
  address formats), and a full unit + widget test suite.

## 0.0.1

- Initial scaffold: public API surface for on-device address pre-screening.
- Placeholder release; engine, OCR, location, and widget implementations
  landed in 0.1.0.
