import 'package:address_verify/src/config.dart';
import 'package:address_verify/src/engine/engine.dart';
import 'package:address_verify/src/models/address.dart';
import 'package:address_verify/src/models/result.dart';
import 'package:address_verify/src/ui/address_form.dart';
import 'package:address_verify/src/ui/doc_type_selector.dart';
import 'package:address_verify/src/ui/theme.dart';
import 'package:address_verify/src/ui/upload_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Themeable, end-to-end capture widget for address pre-screening.
///
/// Drives the flow: document type select -> file upload -> address form ->
/// submit -> [onComplete] with the engine's [AddressVerifyResult].
///
/// The widget owns no business logic; it forwards inputs to
/// [AddressVerifyEngine] and renders engine output. On uncaught engine errors
/// it surfaces a message and invokes [onError], staying mounted on the
/// current step.
class AddressVerifyWidget extends StatefulWidget {
  /// Creates an [AddressVerifyWidget].
  const AddressVerifyWidget({
    required this.config,
    required this.onComplete,
    this.onError,
    @visibleForTesting this.engineFactory,
    super.key,
  });

  /// Engine + UI configuration.
  final AddressVerifyConfig config;

  /// Invoked when the engine finishes producing a result.
  final void Function(AddressVerifyResult result) onComplete;

  /// Optional error sink for unexpected engine failures.
  final void Function(Object error, StackTrace st)? onError;

  /// Tests-only factory used to inject a mocked [AddressVerifyEngine]. Not
  /// part of the public contract; production callers should leave this null.
  @visibleForTesting
  final AddressVerifyEngine Function(AddressVerifyConfig config)? engineFactory;

  @override
  State<AddressVerifyWidget> createState() => _AddressVerifyWidgetState();
}

enum _Step { selectingDocType, uploading, enteringAddress, submitting }

class _AddressVerifyWidgetState extends State<AddressVerifyWidget> {
  late final AddressVerifyEngine _engine =
      widget.engineFactory?.call(widget.config) ??
          AddressVerifyEngine(widget.config);

  _Step _step = _Step.selectingDocType;
  DocumentType? _docType;
  PlatformFile? _file;
  TypedAddress? _address;
  String _fullName = '';
  String? _errorMessage;

  bool get _canNextFromDocType => _docType != null;
  bool get _canNextFromUpload => _file != null;
  bool get _canSubmit {
    if (_address == null) return false;
    if (widget.config.matchName && _fullName.isEmpty) return false;
    return true;
  }

  void _goTo(_Step step) {
    setState(() {
      _step = step;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _step = _Step.submitting;
      _errorMessage = null;
    });
    try {
      final result = await _engine.verify(
        file: _file!,
        typedAddress: _address!,
        documentType: _docType!,
        fullName: widget.config.matchName ? _fullName : null,
      );
      if (!mounted) return;
      widget.onComplete(result);
      // Stay mounted on the last form step so the host can decide what to do.
      setState(() => _step = _Step.enteringAddress);
    } on Object catch (e, st) {
      if (!mounted) return;
      widget.onError?.call(e, st);
      setState(() {
        _step = _Step.enteringAddress;
        _errorMessage = _Strings.errorPrefix(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ResolvedAddressVerifyTheme.of(context, widget.config.theme);
    return Material(
      color: theme.backgroundColor,
      child: SafeArea(
        child: Padding(
          padding: theme.padding,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(step: _step, theme: theme),
                SizedBox(height: theme.sectionSpacing),
                _StepBody(
                  step: _step,
                  theme: theme,
                  config: widget.config,
                  docType: _docType,
                  file: _file,
                  address: _address,
                  fullName: _fullName,
                  onDocTypePicked: (d) => setState(() => _docType = d),
                  onFilePicked: (f) => setState(() => _file = f),
                  onAddressChanged: (a) => setState(() => _address = a),
                  onFullNameChanged: (n) => setState(() => _fullName = n),
                ),
                if (_errorMessage != null) ...[
                  SizedBox(height: theme.fieldSpacing),
                  Text(_errorMessage!, style: theme.errorStyle),
                ],
                SizedBox(height: theme.sectionSpacing),
                _Controls(
                  step: _step,
                  theme: theme,
                  canNextFromDocType: _canNextFromDocType,
                  canNextFromUpload: _canNextFromUpload,
                  canSubmit: _canSubmit,
                  onBack: () {
                    switch (_step) {
                      case _Step.selectingDocType:
                      case _Step.submitting:
                        break;
                      case _Step.uploading:
                        _goTo(_Step.selectingDocType);
                      case _Step.enteringAddress:
                        _goTo(_Step.uploading);
                    }
                  },
                  onNext: () {
                    switch (_step) {
                      case _Step.selectingDocType:
                        if (_canNextFromDocType) _goTo(_Step.uploading);
                      case _Step.uploading:
                        if (_canNextFromUpload) _goTo(_Step.enteringAddress);
                      case _Step.enteringAddress:
                      case _Step.submitting:
                        break;
                    }
                  },
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.step, required this.theme});

  final _Step step;
  final ResolvedAddressVerifyTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_Strings.headerTitle, style: theme.titleStyle),
        SizedBox(height: theme.fieldSpacing / 2),
        Text(_Strings.headerCaption, style: theme.captionStyle),
        SizedBox(height: theme.fieldSpacing),
        _StepIndicator(step: step, theme: theme),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.theme});

  final _Step step;
  final ResolvedAddressVerifyTheme theme;

  @override
  Widget build(BuildContext context) {
    final stepIndex = switch (step) {
      _Step.selectingDocType => 0,
      _Step.uploading => 1,
      _Step.enteringAddress => 2,
      _Step.submitting => 2,
    };
    final labels = [
      _Strings.stepDocType,
      _Strings.stepUpload,
      _Strings.stepAddress,
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= stepIndex
                    ? theme.primaryColor
                    : theme.borderColor,
              ),
            ),
          _StepDot(
            index: i,
            active: i == stepIndex,
            done: i < stepIndex,
            label: labels[i],
            theme: theme,
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.active,
    required this.done,
    required this.label,
    required this.theme,
  });

  final int index;
  final bool active;
  final bool done;
  final String label;
  final ResolvedAddressVerifyTheme theme;

  @override
  Widget build(BuildContext context) {
    final fill = active || done ? theme.primaryColor : theme.surfaceColor;
    final border =
        active || done ? theme.primaryColor : theme.borderColor;
    final fg = active || done ? theme.onPrimaryColor : theme.subduedTextColor;
    final size = theme.minTapTargetSize / 2;
    return Semantics(
      label: '${_Strings.stepPrefix} ${index + 1}: $label',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: border),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: theme.buttonStyle.copyWith(color: fg),
            ),
          ),
          SizedBox(height: theme.fieldSpacing / 4),
          Text(
            label,
            style: active
                ? theme.bodyStyle
                : theme.captionStyle,
          ),
        ],
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.step,
    required this.theme,
    required this.config,
    required this.docType,
    required this.file,
    required this.address,
    required this.fullName,
    required this.onDocTypePicked,
    required this.onFilePicked,
    required this.onAddressChanged,
    required this.onFullNameChanged,
  });

  final _Step step;
  final ResolvedAddressVerifyTheme theme;
  final AddressVerifyConfig config;
  final DocumentType? docType;
  final PlatformFile? file;
  final TypedAddress? address;
  final String fullName;
  final ValueChanged<DocumentType> onDocTypePicked;
  final ValueChanged<PlatformFile> onFilePicked;
  final ValueChanged<TypedAddress?> onAddressChanged;
  final ValueChanged<String> onFullNameChanged;

  @override
  Widget build(BuildContext context) {
    switch (step) {
      case _Step.selectingDocType:
        return _Section(
          title: _Strings.stepDocType,
          theme: theme,
          child: DocTypeSelector(
            documentTypes: config.documentTypes,
            selected: docType,
            theme: config.theme,
            onSelected: onDocTypePicked,
          ),
        );
      case _Step.uploading:
        return _Section(
          title: _Strings.stepUpload,
          theme: theme,
          child: UploadField(
            allowedFormats: config.allowedFormats,
            maxFileSizeMb: config.maxFileSizeMb,
            file: file,
            theme: config.theme,
            onPicked: onFilePicked,
          ),
        );
      case _Step.enteringAddress:
        return _Section(
          title: _Strings.stepAddress,
          theme: theme,
          child: AddressForm(
            initial: address,
            initialFullName: fullName.isEmpty ? null : fullName,
            collectFullName: config.matchName,
            onChanged: onAddressChanged,
            onFullNameChanged: onFullNameChanged,
            theme: config.theme,
          ),
        );
      case _Step.submitting:
        return _Section(
          title: _Strings.stepSubmitting,
          theme: theme,
          child: Padding(
            padding: EdgeInsets.all(theme.fieldSpacing),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.progressColor),
                SizedBox(height: theme.fieldSpacing),
                Text(_Strings.submittingHint, style: theme.captionStyle),
              ],
            ),
          ),
        );
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.theme,
    required this.child,
  });

  final String title;
  final ResolvedAddressVerifyTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.titleStyle),
        SizedBox(height: theme.fieldSpacing),
        child,
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.step,
    required this.theme,
    required this.canNextFromDocType,
    required this.canNextFromUpload,
    required this.canSubmit,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  final _Step step;
  final ResolvedAddressVerifyTheme theme;
  final bool canNextFromDocType;
  final bool canNextFromUpload;
  final bool canSubmit;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final showBack = step == _Step.uploading || step == _Step.enteringAddress;
    final showNext = step == _Step.selectingDocType || step == _Step.uploading;
    final showSubmit = step == _Step.enteringAddress;
    final isSubmitting = step == _Step.submitting;
    final nextEnabled = switch (step) {
      _Step.selectingDocType => canNextFromDocType,
      _Step.uploading => canNextFromUpload,
      _ => false,
    };
    return Row(
      children: [
        if (showBack)
          Expanded(
            child: _Button(
              label: _Strings.back,
              theme: theme,
              primary: false,
              onPressed: isSubmitting ? null : onBack,
            ),
          ),
        if (showBack && (showNext || showSubmit))
          SizedBox(width: theme.fieldSpacing),
        if (showNext)
          Expanded(
            child: _Button(
              label: _Strings.next,
              theme: theme,
              primary: true,
              onPressed: nextEnabled && !isSubmitting ? onNext : null,
            ),
          ),
        if (showSubmit)
          Expanded(
            child: _Button(
              label: _Strings.submit,
              theme: theme,
              primary: true,
              onPressed: canSubmit && !isSubmitting ? onSubmit : null,
            ),
          ),
      ],
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.theme,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final ResolvedAddressVerifyTheme theme;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final bg = primary
        ? (disabled ? theme.disabledColor : theme.primaryColor)
        : theme.surfaceColor;
    final fg = primary ? theme.onPrimaryColor : theme.textColor;
    final border = primary ? bg : theme.borderColor;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: SizedBox(
        height: theme.minTapTargetSize,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(theme.borderRadius),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(theme.borderRadius),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(theme.borderRadius),
                border: Border.all(color: border),
              ),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: theme.fieldSpacing),
              child: Text(
                label,
                style: theme.buttonStyle.copyWith(color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Strings {
  static const headerTitle = 'Address pre-screening';
  static const headerCaption =
      'Returns a confidence score from on-device signals. '
      'Not a verification authority.';
  static const stepPrefix = 'Step';
  static const stepDocType = 'Choose document type';
  static const stepUpload = 'Upload document';
  static const stepAddress = 'Enter address';
  static const stepSubmitting = 'Running pre-screening';
  static const submittingHint =
      'Scanning the document and scoring signals on device.';
  static const back = 'Back';
  static const next = 'Next';
  static const submit = 'Run pre-screening';

  static String errorPrefix(Object e) => 'Could not run pre-screening: $e';
}
