# address_verify — Build Specification & Agent Orchestration

> **For:** Claude Code (subagents via the Task tool)
> **Target:** Open-source Flutter package published to pub.dev
> **Platform scope (v1):** Mobile only — iOS + Android (Google ML Kit OCR)
> **Architecture:** Headless engine core + thin, fully-themeable widget on top

-----

## 0. How to use this document

This is the single source of truth for building `address_verify`. It contains:

1. **The master specification** (Sections 1–7) — non-negotiable contracts every agent must honor.
1. **The agent roster** (Section 8) — scoped subagents, what each owns, and the handoff contract between them.
1. **The execution sequence** (Section 9) — the order Claude Code should dispatch subagents, with gates.
1. **The test gate** (Section 10) — the hard pass/fail criteria that block “done”.

**Rule for the orchestrator:** dispatch subagents in the order given in Section 9. Each subagent receives this full document plus its scoped brief. A subagent may not redefine a public contract from Sections 3–5; if it believes a contract is wrong, it must stop and surface the conflict, not silently change it.

-----

## 1. What this package is (and is not)

`address_verify` is an **on-device address pre-screening library**. It captures a proof-of-address document, runs OCR, and produces a **confidence score** by fusing independent signals.

**It IS:**

- An on-device OCR + fuzzy-match engine for proof-of-address documents.
- A signal-fusion confidence scorer (address match, name-on-document match, GPS location cross-reference).
- A configurable, themeable capture widget — plus a headless engine for bring-your-own-UI.

**It is NOT:**

- A verification authority. It returns a *confidence score*, never a verdict of “verified”. Documentation must consistently use the words **“pre-screening”** and **“confidence”**, never “verified”/“verification authority”.
- A fraud-proof system. On-device signals (especially GPS) are spoofable; the package surfaces spoof indicators (e.g. mocked-location flag) but does not claim to prevent spoofing.
- A network service. The core runs fully offline. No bundled API keys, no required backend.

**Explicitly out of scope for v1:** VPN/IP detection, document authenticity/tampering checks, web/desktop OCR, server components.

-----

## 2. Design principles (apply to every decision)

1. **Headless-first.** All logic lives in `AddressVerifyEngine` and is usable with zero Flutter widgets. The widget is a thin consumer of the engine.
1. **Offline by default.** No network calls in the core path. Location is the only OS-level signal, and it is opt-in.
1. **Optional signals re-normalize.** Confidence is a weighted average over *present* signals only; absent signals do not count as zero. (See Section 5.)
1. **Transparency over black box.** Every confidence result includes a per-signal breakdown explaining the score.
1. **Pluggable OCR.** OCR is behind an interface (`OcrProvider`). ML Kit is the default impl; a developer can inject their own.
1. **Honest naming.** No type, field, doc string, or README line may imply guaranteed verification.

-----

## 3. Public API contract (FROZEN — agents must not alter signatures)

### 3.1 Configuration

```dart
class AddressVerifyConfig {
  final List<DocumentType> documentTypes;     // developer-defined, non-empty
  final List<FileFormat> allowedFormats;      // subset of {pdf, png, jpg}
  final int maxFileSizeMb;                     // default 10
  final ReturnMode returnMode;                 // path | base64
  final bool detectLocation;                   // default false; GPS cross-ref
  final bool matchName;                        // default true; name-on-document
  final SignalWeights signalWeights;           // fusion weights
  final double matchThreshold;                 // strong >= threshold; default 0.75
  final String ocrLanguage;                    // default 'en'
  final AddressVerifyTheme theme;              // UI theming
  final OcrProvider? ocrProvider;              // null => default MlKitOcrProvider

  const AddressVerifyConfig({
    required this.documentTypes,
    this.allowedFormats = const [FileFormat.pdf, FileFormat.png, FileFormat.jpg],
    this.maxFileSizeMb = 10,
    this.returnMode = ReturnMode.path,
    this.detectLocation = false,
    this.matchName = true,
    this.signalWeights = const SignalWeights(),
    this.matchThreshold = 0.75,
    this.ocrLanguage = 'en',
    this.theme = const AddressVerifyTheme(),
    this.ocrProvider,
  });
}

enum FileFormat { pdf, png, jpg }
enum ReturnMode { path, base64 }

class DocumentType {
  final String id;        // stable key, e.g. 'utility_bill'
  final String label;     // display, e.g. 'Utility Bill'
  final String? hint;     // optional helper text
  const DocumentType({required this.id, required this.label, this.hint});
}

class SignalWeights {
  final double address;   // default 0.45
  final double name;      // default 0.25
  final double location;  // default 0.30
  const SignalWeights({this.address = 0.45, this.name = 0.25, this.location = 0.30});
}
```

### 3.2 Inputs

```dart
class TypedAddress {
  final String line1;
  final String? line2;
  final String city;
  final String? state;
  final String? postalCode;
  final String country;        // ISO 3166-1 alpha-2, e.g. 'NG'
  const TypedAddress({
    required this.line1, this.line2, required this.city,
    this.state, this.postalCode, required this.country,
  });
}
```

### 3.3 Result

```dart
class AddressVerifyResult {
  final double confidence;            // 0.0..1.0, fused
  final MatchVerdict verdict;         // strong | partial | weak
  final DocumentType documentType;    // user-selected
  final DocumentFile document;        // path OR base64 per config
  final String extractedText;         // raw OCR
  final ExtractedAddress? extracted;  // best-effort parse, may be null
  final TypedAddress typedAddress;
  final ConfidenceBreakdown breakdown;// per-signal explanation
  final List<VerifyFlag> flags;       // e.g. locationMismatch, mockedLocation
}

enum MatchVerdict { strong, partial, weak }

class DocumentFile {
  final String? path;     // set iff ReturnMode.path
  final String? base64;   // set iff ReturnMode.base64
  final String mimeType;
  final int sizeBytes;
}

class ConfidenceBreakdown {
  final List<SignalScore> signals;    // present signals only
}

class SignalScore {
  final String name;      // 'address' | 'name' | 'location'
  final double score;     // 0.0..1.0 raw
  final double weight;    // re-normalized weight actually applied
  final String? detail;   // human-readable why
}

enum VerifyFlag { addressMismatch, nameNotFound, locationMismatch, mockedLocation, lowOcrConfidence }
```

### 3.4 Engine (headless core)

```dart
class AddressVerifyEngine {
  AddressVerifyEngine(AddressVerifyConfig config);

  /// Full pipeline: validate -> OCR -> match -> fuse -> package.
  Future<AddressVerifyResult> verify({
    required PlatformFile file,
    required TypedAddress typedAddress,
    required DocumentType documentType,
    String? fullName,                 // required iff config.matchName == true
  });

  /// Granular access for custom UIs:
  Future<String> extractText(PlatformFile file);
  AddressMatch matchAddress(TypedAddress typed, String ocrText);
  NameMatch matchName(String fullName, String ocrText);
}
```

### 3.5 OCR provider interface

```dart
abstract class OcrProvider {
  Future<OcrResult> extract(Uint8List imageBytes);
}
class OcrResult {
  final String text;
  final double? meanConfidence;   // 0..1 if available
}
// Default impl: MlKitOcrProvider (google_mlkit_text_recognition)
```

### 3.6 Widget

```dart
class AddressVerifyWidget extends StatefulWidget {
  final AddressVerifyConfig config;
  final void Function(AddressVerifyResult result) onComplete;
  final void Function(Object error, StackTrace st)? onError;
  const AddressVerifyWidget({
    super.key, required this.config, required this.onComplete, this.onError,
  });
}
```

-----

## 4. Confidence fusion algorithm (FROZEN spec)

Compute confidence as a weighted average over **present** signals, re-normalized so present weights sum to 1.

```
present_signals = [address]                         // always present
if matchName:        present_signals += [name]
if detectLocation:   present_signals += [location]

total_weight = sum(weight_i for i in present_signals)
confidence   = sum(score_i * weight_i for i in present_signals) / total_weight
```

**Signal scoring:**

- **address** — token-based fuzzy match between `TypedAddress` and OCR text. Combine Jaccard token overlap (0.4) with weighted critical-token hits (street/number/city, 0.6). Range 0..1.
- **name** — fuzzy presence of `fullName` tokens in OCR text. If name absent → score 0 and flag `nameNotFound`.
- **location** — compare device GPS-resolved country vs `typedAddress.country`. Match → 1.0, mismatch → 0.0 and flag `locationMismatch`. If `position.isMocked` → multiply score by 0.3 and flag `mockedLocation`.

**Verdict mapping:**

```
confidence >= matchThreshold          -> strong
confidence >= matchThreshold * 0.66   -> partial
else                                  -> weak
```

**Normalization rules (apply before matching):** lowercase; strip punctuation `[.,#-/]`; collapse whitespace; expand common abbreviations (street→st, road→rd, avenue→ave) bidirectionally. Document the abbreviation table; make it overridable later (not v1).

-----

## 5. File handling rules

- Validate format against `allowedFormats` and size against `maxFileSizeMb` BEFORE any processing; throw `UnsupportedFileException` / `FileTooLargeException`.
- **PDF:** rasterize page 1 (and up to 3 pages if page 1 yields < 20 chars OCR) to images for OCR. Images pass through.
- **Packaging:** honor `returnMode`. `path` → return temp file path + mime + size. `base64` → return base64 string + mime + size. Exactly one of `path`/`base64` is non-null.
- Compute and expose nothing sensitive; do not log file contents.

-----

## 6. Dependencies (pin major versions; agent picks latest compatible)

```yaml
dependencies:
  flutter: { sdk: flutter }
  file_picker: ^8.0.0
  google_mlkit_text_recognition: ^0.13.0
  image: ^4.0.0
  pdfx: ^2.6.0            # or pdf_render — agent chooses, must rasterize on iOS+Android
  geolocator: ^12.0.0
  crypto: ^3.0.0
dev_dependencies:
  flutter_test: { sdk: flutter }
  mocktail: ^1.0.0
  very_good_analysis: ^6.0.0
```

Platform setup the agent MUST document in README: iOS `Info.plist` location + camera/photo keys; Android `AndroidManifest.xml` location permissions and `minSdkVersion` for ML Kit.

-----

## 7. Repository layout

```
address_verify/
├── lib/
│   ├── address_verify.dart              # barrel: public exports only
│   └── src/
│       ├── config.dart
│       ├── models/{result,document_file,address,signals}.dart
│       ├── engine/engine.dart
│       ├── engine/file_handler.dart
│       ├── engine/address_matcher.dart
│       ├── engine/name_matcher.dart
│       ├── engine/confidence_engine.dart
│       ├── engine/location_service.dart
│       ├── ocr/ocr_provider.dart
│       ├── ocr/mlkit_ocr_provider.dart
│       └── ui/{address_verify_widget,doc_type_selector,upload_field,address_form,theme}.dart
├── test/                                # mirrors lib/src structure
├── example/                             # runnable demo app, all features wired
├── README.md
├── CHANGELOG.md
├── LICENSE                              # MIT
├── analysis_options.yaml               # very_good_analysis
└── pubspec.yaml
```

-----

## 8. Agent roster (scoped subagents)

Each agent is dispatched via the Task tool with: this full document + its brief below. Each must honor the frozen contracts (Sections 3–5). Output of one feeds the next per Section 9.

### Agent 1 — Architect / Scaffolder

**Owns:** repo skeleton, `pubspec.yaml`, `analysis_options.yaml`, all model classes (Section 3.1–3.3), the public barrel file, and stub signatures for engine + OCR + widget (no logic, just contracts that compile).
**Definition of done:** `flutter analyze` passes with zero issues; `flutter pub get` resolves; all public types from Sections 3 exist and compile; no business logic yet.
**Handoff:** a compiling skeleton where every frozen signature is present.

### Agent 2 — Engine Developer (core logic)

**Owns:** `file_handler`, `address_matcher`, `name_matcher`, `confidence_engine`, `location_service`, `engine`. Implements Sections 4 + 5 exactly.
**Constraints:** pure Dart logic must be unit-testable without a device (inject OCR + location via interfaces; no direct plugin calls inside matchers/fusion). `ConfidenceEngine`, `AddressMatcher`, `NameMatcher` must have ZERO Flutter/plugin imports.
**Handoff:** fully implemented engine with all interfaces mockable.

### Agent 3 — OCR & Platform Integrator

**Owns:** `OcrProvider` interface + `MlKitOcrProvider`, PDF rasterization in `file_handler`, `geolocator` wiring in `location_service`, iOS/Android platform config.
**Constraints:** plugin code isolated to these files only; everything else stays device-agnostic. Provide graceful failures (`OcrUnavailableException`, `LocationPermissionDeniedException`).
**Handoff:** real OCR + location working on device; documented platform setup.

### Agent 4 — UI / Widget Developer

**Owns:** `AddressVerifyWidget` + sub-widgets + `AddressVerifyTheme`. Thin consumer of the engine; no business logic in widgets. Flow: doc-type select → upload → address form → submit → `onComplete`.
**Constraints:** fully themeable via `AddressVerifyTheme`; no hardcoded colors/sizes; accessible (labels, tap targets ≥ 48dp). Widget must never compute confidence itself — only call the engine.
**Handoff:** working themeable widget + the `example/` app wiring every config option.

### Agent 5 — Test Engineer (gate owner)

**Owns:** all of `test/`, runs the gate in Section 10. Writes unit tests for matchers + fusion (golden cases incl. African/Nigerian address formats), file-handler tests (format/size/pdf), engine integration tests with mocked OCR + location, and widget tests for the flow.
**Authority:** may REJECT any prior agent’s output back to that agent with a written defect list. “Done” is not declared until Section 10 passes.
**Handoff:** green test suite + coverage report.

### Agent 6 — Docs & Release Prep

**Owns:** `README.md` (honest “pre-screening” framing, quick start, headless + widget examples, all config options, platform setup, signal/weight explanation, spoofing caveat), `CHANGELOG.md`, `LICENSE` (MIT), dartdoc on all public APIs, pub.dev readiness (`flutter pub publish --dry-run` clean).
**Constraint:** every public symbol has a doc comment; README must not use the word “verified” as a guarantee.
**Handoff:** pub.dev-publishable package.

-----

## 9. Execution sequence (orchestrator dispatch order)

```
Agent 1 (Architect)
   └─ GATE: flutter analyze clean, compiles  ──► if fail, retry Agent 1
Agent 2 (Engine)  +  Agent 3 (OCR/Platform)   [2 may start; 3 after 2's interfaces land]
   └─ GATE: engine compiles, no Flutter imports in pure-logic files
Agent 4 (UI)        [needs engine from 2]
   └─ GATE: example app runs
Agent 5 (Tests)     [needs 2,3,4; THE hard gate — Section 10]
   └─ GATE: Section 10 PASSES  ──► on any fail, bounce defects to the owning agent, re-run
Agent 6 (Docs/Release)
   └─ GATE: pub publish --dry-run clean
```

**Loop rule:** Agent 5 can send work back any number of times. The orchestrator does not advance to Agent 6 until Agent 5 signs off.

-----

## 10. Test gate (hard pass/fail — blocks “done”)

All must be true:

1. `flutter analyze` → **zero** warnings/errors (very_good_analysis lint set).
1. `flutter test` → **all pass**.
1. **Line coverage ≥ 85%** overall; **≥ 95%** on `confidence_engine`, `address_matcher`, `name_matcher` (the logic that determines the score).
1. **Golden matcher cases** present and passing, including at least:
- exact address match → confidence ≈ 1.0, verdict strong
- reordered tokens / abbreviation variants → still strong
- claimed NG, OCR address clearly different → weak, flag `addressMismatch`
- name absent from doc (`matchName=true`) → name signal 0, flag `nameNotFound`
- ≥ 5 messy Nigerian/African-format addresses (informal naming, no postcode) with expected ranges
1. **Re-normalization test:** same inputs with `matchName=false` and `detectLocation=false` produce a confidence computed only over the address signal (weights rescaled), NOT a deflated score.
1. **Location tests:** country match → 1.0; mismatch → 0.0 + `locationMismatch`; `isMocked=true` → score ×0.3 + `mockedLocation` (mocked via injected fake location service).
1. **File-handler tests:** rejects oversize + unsupported format with correct exceptions; PDF rasterizes to non-empty OCR input; `returnMode` path vs base64 each populate exactly one field with correct mime/size.
1. **Widget test:** full flow select→upload→address→submit invokes `onComplete` with a populated result (engine mocked).
1. `flutter pub publish --dry-run` → **no errors**.
1. No public symbol or README line claims guaranteed verification (grep check for “verified”/“verification authority” used as a promise).

-----

## 11. Acceptance summary (paste-back checklist for the orchestrator)

- [ ] Headless `AddressVerifyEngine.verify(...)` works with zero widgets
- [ ] Themeable `AddressVerifyWidget` works end-to-end in `example/`
- [ ] Developer-defined `documentTypes` (not a fixed enum)
- [ ] `returnMode` path/base64 honored
- [ ] Signals: address (always), name (toggle), location (toggle), re-normalized fusion
- [ ] Per-signal `ConfidenceBreakdown` returned
- [ ] ML Kit OCR + PDF rasterization on iOS & Android
- [ ] `detectLocation` toggle + mocked-location flag
- [ ] Section 10 test gate fully green
- [ ] pub.dev dry-run clean, MIT licensed, honest “pre-screening” docs