import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Icon shown at the top of [AppConfirmDialog]. `none` hides the icon.
enum AppConfirmDialogIcon { none, success, warning, danger }

/// Shared confirm/cancel dialog: circular status icon, title, message, and
/// two pill-shaped buttons side by side (Cancel neutral, Confirm accent).
/// Used everywhere the app needs an "are you sure?" style prompt.
class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isLoading;
  final bool isDestructive;
  final AppConfirmDialogIcon icon;

  /// When true, swaps button layout: cancel becomes the primary/accent
  /// action on the right, confirm becomes the outline action on the left.
  /// Used for "are you sure" style prompts where staying is the emphasized
  /// choice (e.g. logout: "Keep Login" primary right, "Logout Anyway"
  /// outline left).
  final bool swapButtonEmphasis;

  /// Extra widget (e.g. a reason text field) shown below the message and
  /// above the action buttons, for dialogs that need more than plain text.
  final Widget? extraContent;

  /// Overrides the icon glyph/color picked by [icon] — for dialogs whose
  /// icon isn't a plain success/warning/danger status (e.g. location-off).
  final String? iconGlyph;
  final Color? iconColor;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = '',
    this.onConfirm,
    this.onCancel,
    this.isLoading = false,
    this.isDestructive = false,
    this.icon = AppConfirmDialogIcon.success,
    this.swapButtonEmphasis = false,
    this.extraContent,
    this.iconGlyph,
    this.iconColor,
  });

  /// Shows the dialog and resolves to `true` when confirmed, `null`
  /// otherwise (cancelled or dismissed). Caller is responsible for closing
  /// the dialog again itself when [onConfirm]/[onCancel] are passed (e.g. to
  /// run an async action first) — omit them to get this default pop-on-tap
  /// behavior.
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = '',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isLoading = false,
    bool isDestructive = false,
    AppConfirmDialogIcon icon = AppConfirmDialogIcon.success,
    bool barrierDismissible = true,
    Widget? extraContent,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => AppConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isLoading: isLoading,
        isDestructive: isDestructive,
        icon: icon,
        extraContent: extraContent,
        onConfirm: onConfirm ?? () => Navigator.of(dialogContext).pop(true),
        onCancel: onCancel ?? () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showCancel = cancelLabel.isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingXXL,
        ThemeConstants.paddingXL,
        ThemeConstants.paddingXXL,
        ThemeConstants.paddingS,
      ),
      actionsPadding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingXL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingXL,
        ThemeConstants.paddingL,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            title,
            textAlign: TextAlign.center,
            style: context.tt.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.cs.onSurface,
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            AppText(
              message,
              textAlign: TextAlign.center,
              style: context.tt.bodyMedium?.copyWith(
                color: context.cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          if (extraContent != null) ...[
            const SizedBox(height: 12),
            extraContent!,
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [Row(children: _buildButtons(context, isLoading, showCancel))],
    );
  }

  List<Widget> _buildButtons(
    BuildContext context,
    bool isLoading,
    bool showCancel,
  ) {
    final cancelButton = Expanded(
      child: AppButton(
        label: cancelLabel,
        variant: swapButtonEmphasis
            ? (isDestructive
                  ? AppButtonVariant.danger
                  : AppButtonVariant.primary)
            : AppButtonVariant.outline,
        color: swapButtonEmphasis ? null : context.cs.onSurfaceVariant,
        height: 38,
        fontSize: 12,
        onPressed: isLoading ? null : onCancel,
      ),
    );
    final confirmButton = Expanded(
      child: AppButton(
        label: confirmLabel,
        variant: swapButtonEmphasis
            ? AppButtonVariant.outline
            : (isDestructive
                  ? AppButtonVariant.danger
                  : AppButtonVariant.primary),
        color: swapButtonEmphasis ? context.cs.onSurfaceVariant : null,
        height: 38,
        fontSize: 12,
        isLoading: isLoading,
        onPressed: isLoading ? null : onConfirm,
      ),
    );

    if (!showCancel) return [confirmButton];

    return swapButtonEmphasis
        ? [confirmButton, const SizedBox(width: 12), cancelButton]
        : [cancelButton, const SizedBox(width: 12), confirmButton];
  }
}
