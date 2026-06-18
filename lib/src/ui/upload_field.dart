import 'package:address_verify/src/config.dart';
import 'package:address_verify/src/ui/theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// File-picker entry point for the capture flow.
///
/// Wraps `file_picker` and surfaces a single button-style affordance. The
/// picker is constrained to the formats declared by [allowedFormats]; oversize
/// or unsupported selections are flagged inline via the resolved theme.
class UploadField extends StatefulWidget {
  /// Creates an [UploadField].
  const UploadField({
    required this.allowedFormats,
    required this.maxFileSizeMb,
    required this.onPicked,
    this.file,
    this.enabled = true,
    this.theme = const AddressVerifyTheme(),
    super.key,
  });

  /// File formats the picker will accept; mirrors the engine config.
  final List<FileFormat> allowedFormats;

  /// Maximum file size the picker will accept, in megabytes.
  final int maxFileSizeMb;

  /// Currently selected file, if any.
  final PlatformFile? file;

  /// Whether the field is interactive.
  final bool enabled;

  /// Invoked with the selected file when validation passes.
  final ValueChanged<PlatformFile> onPicked;

  /// Theme overrides.
  final AddressVerifyTheme theme;

  @override
  State<UploadField> createState() => _UploadFieldState();
}

class _UploadFieldState extends State<UploadField> {
  String? _error;

  Future<void> _pick() async {
    setState(() => _error = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions:
            widget.allowedFormats.map((f) => f.name).toList(),
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      final validation = _validate(picked);
      if (validation != null) {
        setState(() => _error = validation);
        return;
      }
      widget.onPicked(picked);
    } on Object catch (e) {
      setState(() => _error = _Strings.pickerFailed(e));
    }
  }

  String? _validate(PlatformFile file) {
    final ext = (file.extension ?? '').toLowerCase();
    final allowed = widget.allowedFormats.map((f) => f.name).toSet();
    if (!allowed.contains(ext)) {
      return _Strings.unsupportedFormat(ext, allowed);
    }
    final maxBytes = widget.maxFileSizeMb * 1024 * 1024;
    if (file.size > maxBytes) {
      return _Strings.fileTooLarge(widget.maxFileSizeMb);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = ResolvedAddressVerifyTheme.of(context, widget.theme);
    final hasFile = widget.file != null;
    final borderColor = _error != null
        ? resolved.errorColor
        : (hasFile ? resolved.focusedBorderColor : resolved.borderColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: hasFile
              ? _Strings.uploadReplaceLabel
              : _Strings.uploadChooseLabel,
          child: InkWell(
            onTap: widget.enabled ? _pick : null,
            borderRadius: BorderRadius.circular(resolved.borderRadius),
            child: Container(
              constraints:
                  BoxConstraints(minHeight: resolved.minTapTargetSize),
              decoration: BoxDecoration(
                color: resolved.surfaceColor,
                borderRadius: BorderRadius.circular(resolved.borderRadius),
                border: Border.all(color: borderColor),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: resolved.padding.left,
                vertical: resolved.fieldSpacing,
              ),
              child: Row(
                children: [
                  Icon(
                    hasFile
                        ? Icons.insert_drive_file_outlined
                        : Icons.upload_file,
                    color: widget.enabled
                        ? resolved.primaryColor
                        : resolved.disabledColor,
                  ),
                  SizedBox(width: resolved.fieldSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasFile
                              ? widget.file!.name
                              : _Strings.uploadChooseLabel,
                          style: resolved.bodyStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasFile) ...[
                          SizedBox(height: resolved.fieldSpacing / 4),
                          Text(
                            _formatSize(widget.file!.size),
                            style: resolved.captionStyle,
                          ),
                        ] else ...[
                          SizedBox(height: resolved.fieldSpacing / 4),
                          Text(
                            _Strings.uploadHint(
                              widget.allowedFormats
                                  .map((f) => f.name.toUpperCase())
                                  .toList(),
                              widget.maxFileSizeMb,
                            ),
                            style: resolved.captionStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          SizedBox(height: resolved.fieldSpacing / 2),
          Text(_error!, style: resolved.errorStyle),
        ],
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class _Strings {
  static const uploadChooseLabel = 'Choose a document';
  static const uploadReplaceLabel = 'Replace document';

  static String uploadHint(List<String> formats, int maxMb) =>
      'Allowed: ${formats.join(", ")} (max ${maxMb}MB)';

  static String unsupportedFormat(String ext, Set<String> allowed) =>
      'Unsupported format "${ext.isEmpty ? "unknown" : ext}". '
      'Allowed: ${allowed.map((e) => e.toUpperCase()).join(", ")}.';

  static String fileTooLarge(int maxMb) =>
      'File is larger than ${maxMb}MB. Please choose a smaller file.';

  static String pickerFailed(Object e) =>
      'Could not open the file picker: $e';
}
