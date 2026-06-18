import 'dart:io';
import 'dart:typed_data';

import 'package:address_verify/address_verify.dart';
import 'package:address_verify/src/engine/file_handler.dart';
import 'package:address_verify/src/ui/upload_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final Uint8List _onePixelPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class _StubOcrProvider implements OcrProvider {
  _StubOcrProvider(this.text);
  final String text;
  int calls = 0;

  @override
  Future<OcrResult> extract(Uint8List imageBytes) async {
    calls++;
    return OcrResult(text: text);
  }
}

const _utilityBill =
    DocumentType(id: 'utility_bill', label: 'Utility Bill');

const _config = AddressVerifyConfig(
  documentTypes: [_utilityBill],
  matchName: false,
);

void main() {
  testWidgets(
      'full flow select -> upload -> address -> submit invokes onComplete',
      (tester) async {
    AddressVerifyResult? captured;
    Object? unexpectedError;
    final ocr = _StubOcrProvider('123 Main Street Lagos');
    final tmp = Directory.systemTemp.createTempSync('av_widget_');
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddressVerifyWidget(
              config: _config,
              onComplete: (r) => captured = r,
              onError: (e, _) => unexpectedError = e,
              engineFactory: (c) => AddressVerifyEngine(
                c,
                ocrProviderOverride: ocr,
                tempDirectory: tmp,
              ),
            ),
          ),
        ),
      );

      // Step 1: choose document type. Tap the tile.
      expect(find.text('Choose document type'), findsWidgets);
      await tester.tap(find.text('Utility Bill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: upload. We can not drive the platform file picker, so we drive
      // the widget by directly invoking onPicked on the inner UploadField.
      final uploadFinder = find.byWidgetPredicate((w) => w is UploadField);
      expect(uploadFinder, findsOneWidget);
      final upload = tester.widget<UploadField>(uploadFinder);
      upload.onPicked(
        PlatformFile(
          name: 'doc.png',
          size: _onePixelPng.lengthInBytes,
          bytes: _onePixelPng,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 3: address form. Drive each field by its label. We use the
      // first TextField for each label (the controller is the form's).
      final line1Field = find.widgetWithText(TextField, 'Street address');
      final cityField = find.widgetWithText(TextField, 'City');
      final countryField = find.widgetWithText(TextField, 'Country (ISO-2)');
      expect(
        line1Field,
        findsOneWidget,
        reason: 'line1 field should be present on step 3',
      );
      expect(
        cityField,
        findsOneWidget,
        reason: 'city field should be present on step 3',
      );
      expect(
        countryField,
        findsOneWidget,
        reason: 'country field should be present on step 3',
      );
      await tester.ensureVisible(line1Field);
      await tester.enterText(line1Field, '123 Main Street');
      await tester.pump();
      await tester.ensureVisible(cityField);
      await tester.enterText(cityField, 'Lagos');
      await tester.pump();
      await tester.ensureVisible(countryField);
      await tester.enterText(countryField, 'NG');
      await tester.pump();
      // Sanity check: the values landed in the controllers and the address
      // step is on screen.
      expect(
        tester.widget<TextField>(line1Field).controller!.text,
        '123 Main Street',
      );
      expect(
        tester.widget<TextField>(cityField).controller!.text,
        'Lagos',
      );
      expect(
        tester.widget<TextField>(countryField).controller!.text,
        'NG',
      );
      expect(find.text('Enter address'), findsWidgets);
      final submitFinder = find.text('Run pre-screening');
      expect(submitFinder, findsOneWidget);

      // Submit. The submit handler is async and the file_handler writes the
      // returned document to a real temp file, so we need real time + a few
      // pumps for the resulting setState to settle. pumpAndSettle would
      // loop on the CircularProgressIndicator animation, so we step
      // manually.
      await tester.tap(submitFinder);
      await tester.pump();
      for (var i = 0; i < 30 && captured == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      expect(
        unexpectedError,
        isNull,
        reason: 'engine raised: $unexpectedError',
      );
      expect(
        captured,
        isNotNull,
        reason: 'onComplete was never invoked (OCR calls=${ocr.calls}).',
      );
      expect(captured!.confidence, greaterThan(0.7));
      expect(captured!.verdict, MatchVerdict.strong);
      expect(captured!.documentType.id, _utilityBill.id);
      expect(captured!.extractedText, contains('Main'));
      expect(captured!.typedAddress.line1, '123 Main Street');
      expect(captured!.typedAddress.city, 'Lagos');
      expect(captured!.typedAddress.country, 'NG');
      expect(captured!.document.mimeType, 'image/png');
    } finally {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  testWidgets('engine errors are caught and forwarded to onError',
      (tester) async {
    Object? caughtError;
    final tmp = Directory.systemTemp.createTempSync('av_widget_err_');
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    try {
      // Misconfigure: build the engine without a valid OCR provider override
      // and with the unconfigured PDF rasterizer wired in via the default
      // FileHandler. Feed a PDF so rasterization fires the error path.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddressVerifyWidget(
              config: _config,
              onComplete: (_) {},
              onError: (e, _) => caughtError = e,
              engineFactory: (c) => AddressVerifyEngine(
                c,
                fileHandler: FileHandler(config: c),
                ocrProviderOverride: _StubOcrProvider('whatever'),
                tempDirectory: tmp,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Utility Bill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Pick a PDF; the unconfigured rasterizer will throw.
      final upload = tester.widget<UploadField>(
        find.byWidgetPredicate((w) => w is UploadField),
      );
      upload.onPicked(
        PlatformFile(
          name: 'doc.pdf',
          size: 4,
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Street address'),
        '123 Main Street',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'City'),
        'Lagos',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Country (ISO-2)'),
        'NG',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Run pre-screening'));
      await tester.pump();
      for (var i = 0; i < 30 && caughtError == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      expect(caughtError, isNotNull);
      // The widget shows an error banner instead of advancing.
      expect(
        find.textContaining('Could not run pre-screening'),
        findsOneWidget,
      );
    } finally {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  testWidgets('back button on upload step returns to doc-type step',
      (tester) async {
    final tmp = Directory.systemTemp.createTempSync('av_widget_back_');
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddressVerifyWidget(
              config: _config,
              onComplete: (_) {},
              engineFactory: (c) => AddressVerifyEngine(
                c,
                ocrProviderOverride: _StubOcrProvider('foo'),
                tempDirectory: tmp,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Utility Bill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Back from upload should land back on the doc-type selector.
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Choose document type'), findsWidgets);
    } finally {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  testWidgets('collectFullName path renders a full-name field and submits',
      (tester) async {
    AddressVerifyResult? captured;
    final tmp = Directory.systemTemp.createTempSync('av_widget_name_');
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    try {
      // matchName=true forces the form to also collect a full name.
      const cfg = AddressVerifyConfig(documentTypes: [_utilityBill]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddressVerifyWidget(
              config: cfg,
              onComplete: (r) => captured = r,
              engineFactory: (c) => AddressVerifyEngine(
                c,
                ocrProviderOverride:
                    _StubOcrProvider('Ada Lovelace 123 Main Street Lagos'),
                tempDirectory: tmp,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Utility Bill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      final upload = tester.widget<UploadField>(
        find.byWidgetPredicate((w) => w is UploadField),
      );
      upload.onPicked(
        PlatformFile(
          name: 'doc.png',
          size: _onePixelPng.lengthInBytes,
          bytes: _onePixelPng,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Full name field is the first new field on this step.
      expect(find.widgetWithText(TextField, 'Full name'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Full name'),
        'Ada Lovelace',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Street address'),
        '123 Main Street',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'City'),
        'Lagos',
      );

      // Type a single-char country first to exercise the validation branch
      // that sets a non-null countryError, then a valid 2-char code.
      await tester.enterText(
        find.widgetWithText(TextField, 'Country (ISO-2)'),
        'N',
      );
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Country (ISO-2)'),
        'NG',
      );
      await tester.pump();

      await tester.tap(find.text('Run pre-screening'));
      await tester.pump();
      for (var i = 0; i < 30 && captured == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(captured, isNotNull);
      // name signal is present with a perfect score.
      final nameSignal = captured!.breakdown.signals.firstWhere(
        (s) => s.name == 'name',
      );
      expect(nameSignal.score, 1);
    } finally {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  testWidgets('renders header, caption, and step indicators', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddressVerifyWidget(
            config: _config,
            onComplete: (_) {},
            engineFactory: (c) => AddressVerifyEngine(
              c,
              ocrProviderOverride: _StubOcrProvider(''),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Address pre-screening'), findsOneWidget);
    expect(
      find.textContaining('Not a verification authority'),
      findsOneWidget,
    );
    expect(find.text('Utility Bill'), findsOneWidget);
  });
}
