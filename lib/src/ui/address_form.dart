import 'package:address_verify/src/models/address.dart';
import 'package:address_verify/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Form that collects a [TypedAddress] from the user.
///
/// Fires [onChanged] only when the currently-entered values constitute a
/// minimally-valid address (non-empty `line1`, `city`, and a 2-letter
/// `country`). When [collectFullName] is enabled, also collects a full name
/// for the optional name-on-document match signal.
///
/// v2 TODO: replace the country text input with a proper picker. Kept as a
/// plain field for v1 to avoid pulling in a country-list dependency.
class AddressForm extends StatefulWidget {
  /// Creates an [AddressForm].
  const AddressForm({
    required this.onChanged,
    this.initial,
    this.initialFullName,
    this.collectFullName = false,
    this.onFullNameChanged,
    this.enabled = true,
    this.theme = const AddressVerifyTheme(),
    super.key,
  });

  /// Optional initial address to pre-fill the form with.
  final TypedAddress? initial;

  /// Optional initial full name to pre-fill, used when [collectFullName] is on.
  final String? initialFullName;

  /// Whether to also collect a full name (when `matchName` is enabled).
  final bool collectFullName;

  /// Whether the form is interactive.
  final bool enabled;

  /// Invoked with `null` when the address is incomplete, and a populated
  /// [TypedAddress] once all required fields are non-empty and the country is
  /// a 2-letter code.
  final ValueChanged<TypedAddress?> onChanged;

  /// Invoked on every full-name change. Used only when [collectFullName] is on.
  final ValueChanged<String>? onFullNameChanged;

  /// Theme overrides.
  final AddressVerifyTheme theme;

  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _postal;
  late final TextEditingController _country;
  late final TextEditingController _fullName;

  String? _countryError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _line1 = TextEditingController(text: initial?.line1 ?? '');
    _line2 = TextEditingController(text: initial?.line2 ?? '');
    _city = TextEditingController(text: initial?.city ?? '');
    _state = TextEditingController(text: initial?.state ?? '');
    _postal = TextEditingController(text: initial?.postalCode ?? '');
    _country = TextEditingController(text: initial?.country ?? '');
    _fullName = TextEditingController(text: widget.initialFullName ?? '');
    for (final c in [_line1, _line2, _city, _state, _postal, _country]) {
      c.addListener(_emitAddress);
    }
    _fullName.addListener(_emitFullName);
  }

  @override
  void dispose() {
    for (final c in [_line1, _line2, _city, _state, _postal, _country]) {
      c.dispose();
    }
    _fullName.dispose();
    super.dispose();
  }

  void _emitAddress() {
    final country = _country.text.trim().toUpperCase();
    String? countryError;
    if (country.isNotEmpty && country.length != 2) {
      countryError = _Strings.countryFormat;
    }
    if (_countryError != countryError) {
      setState(() => _countryError = countryError);
    }
    if (_line1.text.trim().isEmpty ||
        _city.text.trim().isEmpty ||
        country.length != 2) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(
      TypedAddress(
        line1: _line1.text.trim(),
        line2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim().isEmpty ? null : _state.text.trim(),
        postalCode:
            _postal.text.trim().isEmpty ? null : _postal.text.trim(),
        country: country,
      ),
    );
  }

  void _emitFullName() {
    widget.onFullNameChanged?.call(_fullName.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final resolved = ResolvedAddressVerifyTheme.of(context, widget.theme);
    final gap = SizedBox(height: resolved.fieldSpacing);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.collectFullName) ...[
          _Field(
            controller: _fullName,
            label: _Strings.fullName,
            theme: resolved,
            enabled: widget.enabled,
            textInputAction: TextInputAction.next,
          ),
          gap,
        ],
        _Field(
          controller: _line1,
          label: _Strings.line1,
          theme: resolved,
          enabled: widget.enabled,
          textInputAction: TextInputAction.next,
        ),
        gap,
        _Field(
          controller: _line2,
          label: _Strings.line2,
          theme: resolved,
          enabled: widget.enabled,
          textInputAction: TextInputAction.next,
        ),
        gap,
        _Field(
          controller: _city,
          label: _Strings.city,
          theme: resolved,
          enabled: widget.enabled,
          textInputAction: TextInputAction.next,
        ),
        gap,
        _Field(
          controller: _state,
          label: _Strings.state,
          theme: resolved,
          enabled: widget.enabled,
          textInputAction: TextInputAction.next,
        ),
        gap,
        _Field(
          controller: _postal,
          label: _Strings.postalCode,
          theme: resolved,
          enabled: widget.enabled,
          textInputAction: TextInputAction.next,
        ),
        gap,
        _Field(
          controller: _country,
          label: _Strings.country,
          helperText: _Strings.countryHelper,
          theme: resolved,
          enabled: widget.enabled,
          maxLength: 2,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
            _UpperCaseFormatter(),
          ],
          textInputAction: TextInputAction.done,
          errorText: _countryError,
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.theme,
    required this.enabled,
    this.helperText,
    this.errorText,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final ResolvedAddressVerifyTheme theme;
  final bool enabled;
  final String? helperText;
  final String? errorText;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(theme.borderRadius),
      borderSide: BorderSide(color: theme.borderColor),
    );
    return Semantics(
      label: label,
      textField: true,
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLength: maxLength,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        textInputAction: textInputAction,
        style: theme.bodyStyle,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: theme.captionStyle,
          helperText: helperText,
          helperStyle: theme.captionStyle,
          errorText: errorText,
          errorStyle: theme.errorStyle,
          counterText: '',
          filled: true,
          fillColor: theme.surfaceColor,
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(theme.borderRadius),
            borderSide:
                BorderSide(color: theme.focusedBorderColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(theme.borderRadius),
            borderSide: BorderSide(color: theme.errorColor),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(theme.borderRadius),
            borderSide: BorderSide(color: theme.errorColor, width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(theme.borderRadius),
            borderSide: BorderSide(color: theme.disabledColor),
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class _Strings {
  static const line1 = 'Street address';
  static const line2 = 'Apartment, suite, etc. (optional)';
  static const city = 'City';
  static const state = 'State / region (optional)';
  static const postalCode = 'Postal code (optional)';
  static const country = 'Country (ISO-2)';
  static const countryHelper = 'Two-letter country code, e.g. NG, US, GB';
  static const countryFormat = 'Enter the 2-letter ISO country code.';
  static const fullName = 'Full name';
}
