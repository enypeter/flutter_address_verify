import 'package:address_verify/address_verify.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ExampleApp());
}

/// Runnable demo app that wires every [AddressVerifyConfig] option to a
/// control on screen, rebuilding [AddressVerifyWidget] with a fresh key
/// whenever the configuration changes.
class ExampleApp extends StatelessWidget {
  /// Creates an [ExampleApp].
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'address_verify example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _DemoHome(),
    );
  }
}

class _DemoHome extends StatefulWidget {
  const _DemoHome();

  @override
  State<_DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  static const _allDocTypes = <DocumentType>[
    DocumentType(
      id: 'utility_bill',
      label: 'Utility Bill',
      hint: 'Power, water, or internet bill issued in the last 90 days.',
    ),
    DocumentType(
      id: 'bank_statement',
      label: 'Bank Statement',
      hint: 'Statement showing your name and address.',
    ),
    DocumentType(
      id: 'rental_agreement',
      label: 'Rental Agreement',
      hint: 'Signed lease or tenancy contract.',
    ),
  ];

  // Live config controls.
  final _selectedDocTypes = <DocumentType>{
    _allDocTypes[0],
    _allDocTypes[1],
  };
  ReturnMode _returnMode = ReturnMode.path;
  bool _detectLocation = false;
  bool _matchName = true;
  double _addressWeight = 0.45;
  double _nameWeight = 0.25;
  double _locationWeight = 0.30;
  Color _seed = Colors.indigo;

  AddressVerifyResult? _result;
  Object? _lastError;

  int _widgetKeyEpoch = 0;

  AddressVerifyConfig _buildConfig() {
    return AddressVerifyConfig(
      documentTypes: _selectedDocTypes.toList(),
      returnMode: _returnMode,
      detectLocation: _detectLocation,
      matchName: _matchName,
      signalWeights: SignalWeights(
        address: _addressWeight,
        name: _nameWeight,
        location: _locationWeight,
      ),
      theme: AddressVerifyTheme(
        primaryColor: _seed,
        focusedBorderColor: _seed,
      ),
    );
  }

  void _bumpKey() {
    setState(() {
      _widgetKeyEpoch++;
      _result = null;
      _lastError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = _buildConfig();
    final canShowWidget = _selectedDocTypes.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('address_verify example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsPanel(
            allDocTypes: _allDocTypes,
            selectedDocTypes: _selectedDocTypes,
            returnMode: _returnMode,
            detectLocation: _detectLocation,
            matchName: _matchName,
            addressWeight: _addressWeight,
            nameWeight: _nameWeight,
            locationWeight: _locationWeight,
            seed: _seed,
            onDocTypeToggled: (t, {required on}) {
              setState(() {
                if (on) {
                  _selectedDocTypes.add(t);
                } else {
                  _selectedDocTypes.remove(t);
                }
              });
              _bumpKey();
            },
            onReturnModeChanged: (m) {
              setState(() => _returnMode = m);
              _bumpKey();
            },
            onDetectLocationChanged: (v) {
              setState(() => _detectLocation = v);
              _bumpKey();
            },
            onMatchNameChanged: (v) {
              setState(() => _matchName = v);
              _bumpKey();
            },
            onAddressWeightChanged: (v) {
              setState(() => _addressWeight = v);
              _bumpKey();
            },
            onNameWeightChanged: (v) {
              setState(() => _nameWeight = v);
              _bumpKey();
            },
            onLocationWeightChanged: (v) {
              setState(() => _locationWeight = v);
              _bumpKey();
            },
            onSeedChanged: (c) {
              setState(() => _seed = c);
              _bumpKey();
            },
          ),
          const Divider(height: 32),
          if (!canShowWidget)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select at least one document type to enable the widget.',
              ),
            )
          else
            AddressVerifyWidget(
              key: ValueKey('verify-$_widgetKeyEpoch'),
              config: config,
              onComplete: (result) {
                setState(() {
                  _result = result;
                  _lastError = null;
                });
              },
              onError: (error, stack) {
                setState(() => _lastError = error);
              },
            ),
          if (_lastError != null) ...[
            const SizedBox(height: 16),
            _ErrorPanel(error: _lastError!),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            _ResultPanel(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.allDocTypes,
    required this.selectedDocTypes,
    required this.returnMode,
    required this.detectLocation,
    required this.matchName,
    required this.addressWeight,
    required this.nameWeight,
    required this.locationWeight,
    required this.seed,
    required this.onDocTypeToggled,
    required this.onReturnModeChanged,
    required this.onDetectLocationChanged,
    required this.onMatchNameChanged,
    required this.onAddressWeightChanged,
    required this.onNameWeightChanged,
    required this.onLocationWeightChanged,
    required this.onSeedChanged,
  });

  final List<DocumentType> allDocTypes;
  final Set<DocumentType> selectedDocTypes;
  final ReturnMode returnMode;
  final bool detectLocation;
  final bool matchName;
  final double addressWeight;
  final double nameWeight;
  final double locationWeight;
  final Color seed;
  final void Function(DocumentType type, {required bool on}) onDocTypeToggled;
  final ValueChanged<ReturnMode> onReturnModeChanged;
  final ValueChanged<bool> onDetectLocationChanged;
  final ValueChanged<bool> onMatchNameChanged;
  final ValueChanged<double> onAddressWeightChanged;
  final ValueChanged<double> onNameWeightChanged;
  final ValueChanged<double> onLocationWeightChanged;
  final ValueChanged<Color> onSeedChanged;

  static const _seedChoices = <Color>[
    Colors.indigo,
    Colors.teal,
    Colors.deepOrange,
    Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Configuration', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Document types', style: theme.textTheme.titleSmall),
        Wrap(
          spacing: 8,
          children: [
            for (final t in allDocTypes)
              FilterChip(
                label: Text(t.label),
                selected: selectedDocTypes.any((s) => s.id == t.id),
                onSelected: (on) => onDocTypeToggled(t, on: on),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Return mode', style: theme.textTheme.titleSmall),
        SegmentedButton<ReturnMode>(
          segments: const [
            ButtonSegment(value: ReturnMode.path, label: Text('path')),
            ButtonSegment(value: ReturnMode.base64, label: Text('base64')),
          ],
          selected: {returnMode},
          onSelectionChanged: (s) => onReturnModeChanged(s.first),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Detect location (GPS cross-reference)'),
          value: detectLocation,
          onChanged: onDetectLocationChanged,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Match name on document'),
          value: matchName,
          onChanged: onMatchNameChanged,
        ),
        const SizedBox(height: 8),
        Text('Signal weights', style: theme.textTheme.titleSmall),
        _WeightSlider(
          label: 'address',
          value: addressWeight,
          onChanged: onAddressWeightChanged,
        ),
        _WeightSlider(
          label: 'name',
          value: nameWeight,
          onChanged: onNameWeightChanged,
        ),
        _WeightSlider(
          label: 'location',
          value: locationWeight,
          onChanged: onLocationWeightChanged,
        ),
        const SizedBox(height: 8),
        Text('Theme primary color', style: theme.textTheme.titleSmall),
        Wrap(
          spacing: 8,
          children: [
            for (final c in _seedChoices)
              GestureDetector(
                onTap: () => onSeedChanged(c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.toARGB32() == seed.toARGB32()
                          ? theme.colorScheme.onSurface
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WeightSlider extends StatelessWidget {
  const _WeightSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text('$label  ${value.toStringAsFixed(2)}'),
        ),
        Expanded(
          child: Slider(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'onError: $error',
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result});

  final AddressVerifyResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (result.confidence * 100).toStringAsFixed(1);
    final docInfo = result.document.path != null
        ? 'file at: ${result.document.path}'
        : 'base64 (length ${result.document.base64?.length ?? 0})';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Result', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Confidence: $percent%'),
          Text('Verdict: ${result.verdict.name}'),
          Text('Document: ${result.documentType.label}'),
          Text(
            'Mime: ${result.document.mimeType} | '
            '${result.document.sizeBytes} bytes',
          ),
          Text(docInfo),
          const SizedBox(height: 8),
          Text('Flags', style: theme.textTheme.titleSmall),
          if (result.flags.isEmpty)
            const Text('(none)')
          else
            Wrap(
              spacing: 6,
              children: [
                for (final f in result.flags) Chip(label: Text(f.name)),
              ],
            ),
          const SizedBox(height: 8),
          Text('Signal breakdown', style: theme.textTheme.titleSmall),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: result.breakdown.signals.length,
            itemBuilder: (context, i) {
              final s = result.breakdown.signals[i];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${s.name}  score ${s.score.toStringAsFixed(2)}'),
                subtitle: Text(
                  'weight ${s.weight.toStringAsFixed(2)}'
                  '${s.detail != null ? "  ·  ${s.detail}" : ""}',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
