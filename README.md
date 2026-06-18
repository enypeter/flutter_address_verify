# address_verify

On-device proof-of-address pre-screening for Flutter. `address_verify`
captures a proof-of-address document, runs OCR, and produces a **confidence
score** with a per-signal breakdown. This package is not a verification authority
and produces no guaranteed verification verdict. On-device signals such as GPS
are spoofable; the package surfaces spoof indicators (e.g. mocked-location
flag) but does not claim to prevent spoofing. Use the score and breakdown as
input to your own pre-screening flow.

## What this is

- An on-device OCR + fuzzy-match engine for proof-of-address documents.
- A signal-fusion confidence scorer (address match, name-on-document match,
  optional GPS country cross-reference).
- A configurable, themeable capture widget — plus a headless engine for
  bring-your-own-UI.

## What this is NOT

- This package is not a verification authority. The result is a confidence
  score, not a verdict.
- A fraud-proof system. GPS and on-device readings are spoofable.
- A network service. The core runs fully offline; no API keys, no backend.

Out of scope for the current release: VPN/IP detection, document
authenticity/tampering checks, web/desktop OCR, server components.

## Install

```sh
flutter pub add address_verify
```

Platform: iOS + Android. See **Platform setup** below for required
permissions and SDK levels.

## Quick start — widget

```dart
import 'package:address_verify/address_verify.dart';
import 'package:flutter/material.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = AddressVerifyConfig(
      documentTypes: const [
        DocumentType(id: 'utility_bill', label: 'Utility Bill'),
        DocumentType(id: 'bank_statement', label: 'Bank Statement'),
      ],
      matchName: true,
      detectLocation: false,
    );

    return Scaffold(
      body: AddressVerifyWidget(
        config: config,
        onComplete: (result) {
          debugPrint('confidence=${result.confidence} verdict=${result.verdict}');
        },
        onError: (error, stack) {
          debugPrint('pre-screening failed: $error');
        },
      ),
    );
  }
}
```

## Quick start — headless engine

```dart
import 'package:address_verify/address_verify.dart';
import 'package:file_picker/file_picker.dart';

Future<void> run(PlatformFile pickedFile) async {
  final engine = AddressVerifyEngine(
    AddressVerifyConfig(
      documentTypes: const [
        DocumentType(id: 'utility_bill', label: 'Utility Bill'),
      ],
      matchName: true,
    ),
  );

  final result = await engine.verify(
    file: pickedFile,
    typedAddress: const TypedAddress(
      line1: '12 Adeola Odeku Street',
      city: 'Lagos',
      country: 'NG',
    ),
    documentType: const DocumentType(
      id: 'utility_bill',
      label: 'Utility Bill',
    ),
    fullName: 'Adaeze Okeke',
  );

  print('confidence: ${result.confidence}');
  print('verdict:    ${result.verdict}');
  for (final s in result.breakdown.signals) {
    print('  ${s.name}: score=${s.score} weight=${s.weight} (${s.detail})');
  }
}
```

The engine also exposes granular helpers (`extractText`, `matchAddress`,
`matchName`) for callers building a custom UI.

## Configuration

`AddressVerifyConfig` controls the engine and the widget. Every field has a
default; only `documentTypes` is required.

| Field            | Type                  | Default                           | Meaning                                                                                  |
| ---------------- | --------------------- | --------------------------------- | ---------------------------------------------------------------------------------------- |
| `documentTypes`  | `List<DocumentType>`  | required, non-empty               | Document types the user may select.                                                      |
| `allowedFormats` | `List<FileFormat>`    | `[pdf, png, jpg]`                 | Accepted file containers; others are rejected before processing.                         |
| `maxFileSizeMb`  | `int`                 | `10`                              | Maximum file size in megabytes; oversize files throw `FileTooLargeException`.            |
| `returnMode`     | `ReturnMode`          | `path`                            | Whether the captured document is returned as a temp file path or a base64 string.        |
| `detectLocation` | `bool`                | `false`                           | Opt in to GPS country cross-reference (adds the `location` signal).                      |
| `matchName`      | `bool`                | `true`                            | Score the supplied full name against OCR text (adds the `name` signal).                  |
| `signalWeights`  | `SignalWeights`       | `address=0.45 name=0.25 loc=0.30` | Weights used when fusing present signals.                                                |
| `matchThreshold` | `double`              | `0.75`                            | Confidence at or above this maps to verdict `strong`.                                    |
| `ocrLanguage`    | `String`              | `'en'`                            | OCR language hint passed to the provider (mapped to ML Kit script).                      |
| `theme`          | `AddressVerifyTheme`  | empty (Material defaults)         | Theming for the widget. All visual values resolve to `Theme.of(context)` when null.      |
| `ocrProvider`    | `OcrProvider?`        | `null`                            | Inject a custom OCR backend. Defaults to `MlKitOcrProvider` when null.                   |

## Signals and confidence

The engine fuses up to three independent signals into a single confidence
score in the range `0.0..1.0`. **Absent signals do not deflate the score** —
present weights are re-normalized to sum to 1 before averaging.

```
present_signals = [address]                          // always present
if matchName:        present_signals += [name]
if detectLocation:   present_signals += [location]

total_weight = sum(weight_i for i in present_signals)
confidence   = sum(score_i * weight_i for i in present_signals) / total_weight
```

### Per-signal scoring

- **address** — token-based fuzzy match between `TypedAddress` and OCR text.
  Combines Jaccard token overlap (weight `0.4`) with weighted critical-token
  hits over street number, the `line1` body, and `city` (weight `0.6`).
- **name** — fraction of `fullName` tokens located in OCR text. If no tokens
  match, the score is `0` and the `nameNotFound` flag is raised.
- **location** — compares the device's GPS-resolved country to
  `typedAddress.country`. Match → `1.0`; mismatch → `0.0` plus a
  `locationMismatch` flag. When the OS reports `position.isMocked`, the
  signal is multiplied by `0.3` and a `mockedLocation` flag is raised.

### Normalization rules

Before matching, both the typed address and OCR text are lowercased,
stripped of `.,#-/` punctuation, whitespace-collapsed, and run through a
small bidirectional abbreviation table (`street ↔ st`, `road ↔ rd`,
`avenue ↔ ave`, etc.) so reordered or abbreviated tokens still match.

### Verdict thresholds

```
confidence >= matchThreshold          -> MatchVerdict.strong
confidence >= matchThreshold * 0.66   -> MatchVerdict.partial
otherwise                             -> MatchVerdict.weak
```

The `ConfidenceBreakdown` returned alongside every result lists each present
signal with its raw score, re-normalized weight, and a short `detail`
string explaining the score.

## Platform setup

`address_verify` wraps `google_mlkit_text_recognition`, `pdfx`,
`geolocator`, and `geocoding`. Your host app must declare the matching
permissions and SDK levels before any of them will work.

### iOS

Add the following keys to `ios/Runner/Info.plist`. Keep the user-facing
strings honest — this is pre-screening, not verification.

```xml
<key>NSCameraUsageDescription</key>
<string>Used to capture proof-of-address documents for on-device pre-screening.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to read proof-of-address documents for on-device pre-screening.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to cross-reference the country on your proof-of-address document for pre-screening.</string>
```

Set the minimum iOS deployment target to `12.0` (ML Kit requirement) in
`ios/Podfile` (`platform :ios, '12.0'`) and on the Runner target in Xcode.

Note: `Position.isMocked` is always reported as `false` on iOS. The
underlying iOS location APIs do not expose a mock-location flag for
foreground readings, so the `mockedLocation` flag never fires on iOS.

### Android

Add the location permissions to
`android/app/src/main/AndroidManifest.xml` inside the `<manifest>` element:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

Set `minSdkVersion` (or `minSdk` in `build.gradle.kts`) to **21 or higher**
in `android/app/build.gradle`/`build.gradle.kts`. ML Kit text recognition
requires API 21+.

```kotlin
defaultConfig {
    minSdk = 21
}
```

Runtime permission prompts are handled by `geolocator` the first time
`detectLocation: true` is used.

### Geocoding caveats

`geocoding` performs reverse geocoding via the platform's built-in service
(`CLGeocoder` on iOS, `Geocoder` on Android). Both providers may require a
network call on first use; offline behaviour is undefined. Both are
rate-limited by the OS — the engine treats failures and empty results as
"country unknown" rather than throwing, so the location signal degrades
gracefully into a `locationMismatch` flag.

### ML Kit caveats

- The first OCR pass downloads the on-device model lazily. On low-storage
  devices this can fail; the engine raises `OcrUnavailableException` in
  that case.
- `meanConfidence` on `OcrResult` is populated on Android only. iOS ML Kit
  does not expose per-line confidence, so the field is `null` and the
  `lowOcrConfidence` flag never fires on iOS.

## Bring-your-own OCR

The default OCR backend is `MlKitOcrProvider`. To swap it (for tests, a
server-backed provider, or a non-Latin script), implement `OcrProvider` and
pass it via `config.ocrProvider`:

```dart
import 'dart:typed_data';
import 'package:address_verify/address_verify.dart';

class MyOcrProvider implements OcrProvider {
  @override
  Future<OcrResult> extract(Uint8List imageBytes) async {
    final text = await myBackend.run(imageBytes);
    return OcrResult(text: text, meanConfidence: null);
  }
}

final config = AddressVerifyConfig(
  documentTypes: const [DocumentType(id: 'utility_bill', label: 'Utility Bill')],
  ocrProvider: MyOcrProvider(),
);
```

## Limitations and known caveats

- **GPS is spoofable.** The OS mock-location flag is surfaced as a
  `mockedLocation` advisory but is not a guarantee against rooted devices,
  custom ROMs, or developer-mode tooling.
- **Geocoding is OS-dependent.** On both iOS and Android the first reverse
  geocode may require a network round-trip and is rate-limited by the
  platform. Failures degrade to "country unknown".
- **OCR quality varies by document.** Scans, photos at acute angles, low
  contrast, glossy laminates, and non-Latin scripts all reduce accuracy.
  The default ML Kit configuration is tuned for the Latin script; pass
  `ocrLanguage` or inject your own `OcrProvider` for other scripts.
- **PDF rasterization** uses `pdfx`. The engine renders page 1, and falls
  back through up to three pages when page 1 yields less than 20 characters
  of OCR text.
- **iOS mocked-location** is never flagged (see above).

## License

MIT — see [LICENSE](LICENSE).
