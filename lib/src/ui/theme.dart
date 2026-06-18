import 'package:flutter/material.dart';

/// Theming options for `AddressVerifyWidget` and its sub-widgets.
///
/// Every visual value the widget paints — colors, spacing, radii, text styles
/// — is read from this theme. Fields are nullable; widgets resolve `null`
/// against the ambient `Theme.of(context)` so callers can opt in to overriding
/// piecemeal. The [AddressVerifyTheme.fromMaterial] factory derives a complete
/// theme from a [BuildContext]; the widget layer calls it once and uses the
/// resolved value everywhere.
@immutable
class AddressVerifyTheme {
  /// Creates an [AddressVerifyTheme]. All fields are optional and default to
  /// `null`, in which case the widget layer falls back to [Theme.of].
  const AddressVerifyTheme({
    this.primaryColor,
    this.onPrimaryColor,
    this.backgroundColor,
    this.surfaceColor,
    this.textColor,
    this.subduedTextColor,
    this.borderColor,
    this.focusedBorderColor,
    this.errorColor,
    this.successColor,
    this.warningColor,
    this.progressColor,
    this.disabledColor,
    this.borderRadius,
    this.padding,
    this.fieldSpacing,
    this.sectionSpacing,
    this.minTapTargetSize,
    this.titleStyle,
    this.bodyStyle,
    this.captionStyle,
    this.errorStyle,
    this.buttonStyle,
  });

  /// Builds a fully-populated [AddressVerifyTheme] from the ambient
  /// [ThemeData], with sensible defaults for every value the widget reads.
  factory AddressVerifyTheme.fromMaterial(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final textTheme = t.textTheme;
    return AddressVerifyTheme(
      primaryColor: scheme.primary,
      onPrimaryColor: scheme.onPrimary,
      backgroundColor: scheme.surface,
      surfaceColor: scheme.surfaceContainerHighest,
      textColor: scheme.onSurface,
      subduedTextColor: scheme.onSurfaceVariant,
      borderColor: scheme.outlineVariant,
      focusedBorderColor: scheme.primary,
      errorColor: scheme.error,
      successColor: const Color(0xFF2E7D32),
      warningColor: const Color(0xFFB26A00),
      progressColor: scheme.primary,
      disabledColor: scheme.onSurface.withValues(alpha: 0.38),
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      fieldSpacing: 12,
      sectionSpacing: 24,
      minTapTargetSize: 48,
      titleStyle: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
      bodyStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      captionStyle:
          textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
      buttonStyle: textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
    );
  }

  /// Primary accent color used for buttons and selected states.
  final Color? primaryColor;

  /// Foreground color drawn on top of [primaryColor].
  final Color? onPrimaryColor;

  /// Background color for the widget root.
  final Color? backgroundColor;

  /// Surface color for cards/sections inside the widget.
  final Color? surfaceColor;

  /// Default text color.
  final Color? textColor;

  /// Color used for hint, caption, and secondary text.
  final Color? subduedTextColor;

  /// Default input/border color in the resting state.
  final Color? borderColor;

  /// Border color used when an input is focused.
  final Color? focusedBorderColor;

  /// Color used for error messages and destructive states.
  final Color? errorColor;

  /// Color used to indicate success / strong-match states.
  final Color? successColor;

  /// Color used to indicate warning / partial-match states.
  final Color? warningColor;

  /// Color used by the in-progress indicator while the engine is running.
  final Color? progressColor;

  /// Color used for disabled controls.
  final Color? disabledColor;

  /// Corner radius applied to surfaces and inputs.
  final double? borderRadius;

  /// Outer padding applied to the widget root.
  final EdgeInsets? padding;

  /// Vertical gap between adjacent form fields.
  final double? fieldSpacing;

  /// Vertical gap between flow sections (selectors, forms, action bars).
  final double? sectionSpacing;

  /// Minimum tap-target size in logical pixels (≥ 48 for accessibility).
  final double? minTapTargetSize;

  /// Text style for section titles.
  final TextStyle? titleStyle;

  /// Text style for body copy.
  final TextStyle? bodyStyle;

  /// Text style for hint / caption copy.
  final TextStyle? captionStyle;

  /// Text style for inline error messages.
  final TextStyle? errorStyle;

  /// Text style for action-button labels.
  final TextStyle? buttonStyle;
}

/// Resolves any null fields on an [AddressVerifyTheme] against the ambient
/// [ThemeData], so widgets can read complete, non-null values.
///
/// This is internal to the UI layer; callers configure their look-and-feel by
/// constructing an [AddressVerifyTheme] directly.
@immutable
class ResolvedAddressVerifyTheme {
  /// Builds a [ResolvedAddressVerifyTheme] from [theme] and [context].
  factory ResolvedAddressVerifyTheme.of(
    BuildContext context,
    AddressVerifyTheme theme,
  ) {
    final fallback = AddressVerifyTheme.fromMaterial(context);
    return ResolvedAddressVerifyTheme._(
      primaryColor: theme.primaryColor ?? fallback.primaryColor!,
      onPrimaryColor: theme.onPrimaryColor ?? fallback.onPrimaryColor!,
      backgroundColor: theme.backgroundColor ?? fallback.backgroundColor!,
      surfaceColor: theme.surfaceColor ?? fallback.surfaceColor!,
      textColor: theme.textColor ?? fallback.textColor!,
      subduedTextColor: theme.subduedTextColor ?? fallback.subduedTextColor!,
      borderColor: theme.borderColor ?? fallback.borderColor!,
      focusedBorderColor:
          theme.focusedBorderColor ?? fallback.focusedBorderColor!,
      errorColor: theme.errorColor ?? fallback.errorColor!,
      successColor: theme.successColor ?? fallback.successColor!,
      warningColor: theme.warningColor ?? fallback.warningColor!,
      progressColor: theme.progressColor ?? fallback.progressColor!,
      disabledColor: theme.disabledColor ?? fallback.disabledColor!,
      borderRadius: theme.borderRadius ?? fallback.borderRadius!,
      padding: theme.padding ?? fallback.padding!,
      fieldSpacing: theme.fieldSpacing ?? fallback.fieldSpacing!,
      sectionSpacing: theme.sectionSpacing ?? fallback.sectionSpacing!,
      minTapTargetSize: theme.minTapTargetSize ?? fallback.minTapTargetSize!,
      titleStyle: theme.titleStyle ?? fallback.titleStyle!,
      bodyStyle: theme.bodyStyle ?? fallback.bodyStyle!,
      captionStyle: theme.captionStyle ?? fallback.captionStyle!,
      errorStyle: theme.errorStyle ?? fallback.errorStyle!,
      buttonStyle: theme.buttonStyle ?? fallback.buttonStyle!,
    );
  }

  const ResolvedAddressVerifyTheme._({
    required this.primaryColor,
    required this.onPrimaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.textColor,
    required this.subduedTextColor,
    required this.borderColor,
    required this.focusedBorderColor,
    required this.errorColor,
    required this.successColor,
    required this.warningColor,
    required this.progressColor,
    required this.disabledColor,
    required this.borderRadius,
    required this.padding,
    required this.fieldSpacing,
    required this.sectionSpacing,
    required this.minTapTargetSize,
    required this.titleStyle,
    required this.bodyStyle,
    required this.captionStyle,
    required this.errorStyle,
    required this.buttonStyle,
  });

  /// Primary accent color.
  final Color primaryColor;

  /// Foreground color drawn on top of [primaryColor].
  final Color onPrimaryColor;

  /// Background color for the widget root.
  final Color backgroundColor;

  /// Surface color for cards/sections.
  final Color surfaceColor;

  /// Default text color.
  final Color textColor;

  /// Subdued / secondary text color.
  final Color subduedTextColor;

  /// Input border color in the resting state.
  final Color borderColor;

  /// Input border color when focused.
  final Color focusedBorderColor;

  /// Error color.
  final Color errorColor;

  /// Success color.
  final Color successColor;

  /// Warning color.
  final Color warningColor;

  /// Color used by the in-progress indicator.
  final Color progressColor;

  /// Color used for disabled controls.
  final Color disabledColor;

  /// Corner radius applied to surfaces and inputs.
  final double borderRadius;

  /// Outer padding applied to the widget root.
  final EdgeInsets padding;

  /// Vertical gap between adjacent form fields.
  final double fieldSpacing;

  /// Vertical gap between flow sections.
  final double sectionSpacing;

  /// Minimum tap-target size.
  final double minTapTargetSize;

  /// Text style for section titles.
  final TextStyle titleStyle;

  /// Text style for body copy.
  final TextStyle bodyStyle;

  /// Text style for hint / caption copy.
  final TextStyle captionStyle;

  /// Text style for inline error messages.
  final TextStyle errorStyle;

  /// Text style for action-button labels.
  final TextStyle buttonStyle;
}
