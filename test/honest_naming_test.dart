import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files we want to scan: every Dart source under `lib/` plus the project
/// `README.md` if one exists. Tests and the example app are out of scope —
/// those can use the word "verified" all they want in test setup.
List<File> _filesToScan() {
  final files = <File>[];
  final libDir = Directory('lib');
  if (libDir.existsSync()) {
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
  }
  for (final candidate in [File('README.md'), File('CHANGELOG.md')]) {
    if (candidate.existsSync()) files.add(candidate);
  }
  return files;
}

/// Match whole-word "verified" or "verification authority" (case-insensitive).
final RegExp _suspicious = RegExp(
  r'\b(verified|verification\s+authority)\b',
  caseSensitive: false,
);

/// Phrases that defuse a match. If any of these appear in the same line as a
/// `_suspicious` hit, the line is fine: the package is explicitly denying the
/// promise.
const List<String> _allowedContexts = <String>[
  'not verified',
  'no verification authority',
  'not a verification authority',
  'never "verified',
  "never 'verified",
  'no guaranteed verification',
];

bool _isAllowed(String line) {
  final lower = line.toLowerCase();
  return _allowedContexts.any(lower.contains);
}

void main() {
  test(
      'no public symbol or doc string claims guaranteed verification',
      () {
    final offenders = <String>[];
    for (final file in _filesToScan()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!_suspicious.hasMatch(line)) continue;
        if (_isAllowed(line)) continue;
        offenders.add('${file.path}:${i + 1}: $line');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Found promissory uses of "verified" / "verification authority"'
          ' in shipped code. Each occurrence must either be removed or '
          'paired with an explicit negation ("not verified", '
          '"not a verification authority", etc.).\n${offenders.join('\n')}',
    );
  });
}
