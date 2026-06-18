import 'package:address_verify/src/config.dart';
import 'package:address_verify/src/ui/theme.dart';
import 'package:flutter/material.dart';

/// Lets the user pick which kind of proof-of-address document they are about
/// to upload.
///
/// Renders one selectable row per [documentTypes] entry. Each row meets the
/// minimum tap-target size set on the resolved [AddressVerifyTheme] and is
/// labelled for assistive technology.
class DocTypeSelector extends StatelessWidget {
  /// Creates a [DocTypeSelector].
  const DocTypeSelector({
    required this.documentTypes,
    required this.onSelected,
    this.selected,
    this.theme = const AddressVerifyTheme(),
    super.key,
  });

  /// Document types to present to the user.
  final List<DocumentType> documentTypes;

  /// Currently selected document type, if any.
  final DocumentType? selected;

  /// Invoked when the user picks a document type.
  final ValueChanged<DocumentType> onSelected;

  /// Theme overrides.
  final AddressVerifyTheme theme;

  @override
  Widget build(BuildContext context) {
    assert(documentTypes.isNotEmpty, 'documentTypes must be non-empty');
    final resolved = ResolvedAddressVerifyTheme.of(context, theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < documentTypes.length; i++) ...[
          if (i > 0) SizedBox(height: resolved.fieldSpacing),
          _DocTypeTile(
            type: documentTypes[i],
            selected: selected?.id == documentTypes[i].id,
            theme: resolved,
            onTap: () => onSelected(documentTypes[i]),
          ),
        ],
      ],
    );
  }
}

class _DocTypeTile extends StatelessWidget {
  const _DocTypeTile({
    required this.type,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final DocumentType type;
  final bool selected;
  final ResolvedAddressVerifyTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? theme.focusedBorderColor : theme.borderColor;
    return Semantics(
      button: true,
      selected: selected,
      label: type.label,
      hint: type.hint,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.borderRadius),
        child: Container(
          constraints: BoxConstraints(minHeight: theme.minTapTargetSize),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(theme.borderRadius),
            border: Border.all(color: borderColor),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: theme.padding.left,
            vertical: theme.fieldSpacing,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? theme.primaryColor : theme.subduedTextColor,
              ),
              SizedBox(width: theme.fieldSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(type.label, style: theme.bodyStyle),
                    if (type.hint != null) ...[
                      SizedBox(height: theme.fieldSpacing / 4),
                      Text(type.hint!, style: theme.captionStyle),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
