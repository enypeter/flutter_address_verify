/// On-device proof-of-address pre-screening for Flutter.
///
/// This package returns a confidence score with a per-signal breakdown; it
/// does not assert verification. See the package README for usage and the
/// limitations of on-device signals.
library;

export 'src/config.dart'
    show AddressVerifyConfig, DocumentType, FileFormat, ReturnMode;
export 'src/engine/address_matcher.dart' show AddressMatch;
export 'src/engine/engine.dart' show AddressVerifyEngine;
export 'src/engine/name_matcher.dart' show NameMatch;
export 'src/exceptions.dart'
    show
        AddressVerifyException,
        FileTooLargeException,
        LocationPermissionDeniedException,
        OcrUnavailableException,
        UnsupportedFileException;
export 'src/models/address.dart' show ExtractedAddress, TypedAddress;
export 'src/models/document_file.dart' show DocumentFile;
export 'src/models/result.dart' show AddressVerifyResult, MatchVerdict;
export 'src/models/signals.dart'
    show ConfidenceBreakdown, SignalScore, SignalWeights, VerifyFlag;
export 'src/ocr/mlkit_ocr_provider.dart' show MlKitOcrProvider;
export 'src/ocr/ocr_provider.dart' show OcrProvider, OcrResult;
export 'src/ui/address_verify_widget.dart' show AddressVerifyWidget;
export 'src/ui/theme.dart' show AddressVerifyTheme;
