// Parses `coverage/lcov.info` (produced by `flutter test --coverage`) and
// emits a per-file line-coverage table plus the overall percentage. Also
// writes `coverage/SUMMARY.md` so the gate is reproducible.
//
// Usage:
//   dart run tool/coverage_report.dart
//
// Exit code is 0 unless the overall coverage drops below 85% or any of the
// three critical logic files (`confidence_engine`, `address_matcher`,
// `name_matcher`) drop below 95%, in which case it exits non-zero so CI can
// fail the gate.

import 'dart:io';

class _FileCoverage {
  _FileCoverage(this.path);
  final String path;
  int totalLines = 0;
  int hitLines = 0;

  double get percent => totalLines == 0 ? 0 : (hitLines / totalLines) * 100.0;
}

Future<void> main() async {
  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln('coverage/lcov.info not found. '
        'Run `flutter test --coverage` first.');
    exit(2);
  }

  final files = <String, _FileCoverage>{};
  _FileCoverage? current;
  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      final path = line.substring(3);
      current = files.putIfAbsent(path, () => _FileCoverage(path));
    } else if (line.startsWith('DA:') && current != null) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        final count = int.tryParse(parts[1]) ?? 0;
        current.totalLines++;
        if (count > 0) current.hitLines++;
      }
    } else if (line == 'end_of_record') {
      current = null;
    }
  }

  final sorted = files.values.toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  var totalLines = 0;
  var hitLines = 0;
  for (final f in sorted) {
    totalLines += f.totalLines;
    hitLines += f.hitLines;
  }
  final overall = totalLines == 0 ? 0 : (hitLines / totalLines) * 100.0;

  const criticalNames = <String>{
    'confidence_engine.dart',
    'address_matcher.dart',
    'name_matcher.dart',
  };

  final buffer = StringBuffer()
    ..writeln('# Coverage summary')
    ..writeln()
    ..writeln('Generated from `coverage/lcov.info`.')
    ..writeln()
    ..writeln('| File | Hit | Total | Coverage |')
    ..writeln('| --- | ---: | ---: | ---: |');

  final failures = <String>[];
  for (final f in sorted) {
    final isCritical = criticalNames.any(f.path.endsWith);
    final marker = isCritical ? ' **(critical)**' : '';
    buffer.writeln(
      '| `${f.path}`$marker '
      '| ${f.hitLines} | ${f.totalLines} | ${f.percent.toStringAsFixed(1)}% |',
    );
    if (isCritical && f.percent < 95.0) {
      failures.add('CRITICAL: ${f.path} at ${f.percent.toStringAsFixed(1)}% '
          '(< 95%)');
    }
  }

  buffer
    ..writeln('| **overall** | $hitLines | $totalLines '
        '| ${overall.toStringAsFixed(1)}% |')
    ..writeln();

  if (overall < 85.0) {
    failures.add('OVERALL ${overall.toStringAsFixed(1)}% (< 85%)');
  }

  if (failures.isNotEmpty) {
    buffer
      ..writeln('## Gate FAILED')
      ..writeln();
    for (final f in failures) {
      buffer.writeln('- $f');
    }
  } else {
    buffer.writeln('## Gate PASSED');
  }

  // Persist alongside lcov.info.
  File('coverage/SUMMARY.md').writeAsStringSync(buffer.toString());

  // Mirror to stdout so callers see it in CI logs.
  stdout.write(buffer.toString());

  exit(failures.isEmpty ? 0 : 1);
}
