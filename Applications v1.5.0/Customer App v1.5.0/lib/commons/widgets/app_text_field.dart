import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';
import '../../commons/widgets/app_text.dart';
import '../../core/localization/language_label_key.dart';
import '../../utils/extensions/context_extensions.dart';
import '../../utils/extensions/localization_extensions.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final bool isMobileField;
  final FocusNode? focusNode;
  final TextStyle? hintStyle;
  final BoxConstraints? prefixIconConstraints;
  final BoxConstraints? suffixIconConstraints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final AutovalidateMode? autovalidateMode;
  final bool isRequired;
  final InputBorder? border;
  final bool filled;
  final EdgeInsetsGeometry? contentPadding;
  final bool isDense;
  final TextStyle? style;
  final Color? cursorColor;
  final bool enabled;
  final bool autofocus;

  /// When true, ignores [obscureText]/[suffixIcon] and manages its own
  /// obscure state with a built-in show/hide eye-icon toggle.
  final bool isPassword;

  const AppTextField({
    super.key,
    required this.controller,
    this.hintText = '',
    this.labelText,
    this.isRequired = false,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.isMobileField = false,
    this.focusNode,
    this.hintStyle,
    this.prefixIconConstraints,
    this.suffixIconConstraints,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.border,
    this.filled = true,
    this.contentPadding,
    this.isDense = false,
    this.style,
    this.cursorColor,
    this.enabled = true,
    this.autofocus = false,
    this.isPassword = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure = widget.isPassword ? true : widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borders = AppDecorations.inputBorderSet(
      cs,
      borderRadius: AppRadius.r10,
    );

    final effectiveKeyboardType = widget.isMobileField
        ? TextInputType.phone
        : widget.keyboardType;
    final effectiveFormatters = widget.isMobileField
        ? [FilteringTextInputFormatter.digitsOnly]
        : (widget.inputFormatters ?? []);
    final effectiveHint = widget.isMobileField
        ? context.translate(LanguageLabelKeys.enterMobileNumber)
        : widget.hintText;
    final effectivePrefixIcon = widget.isMobileField
        ? _MobilePrefix(colorScheme: cs)
        : widget.prefixIcon;
    final effectiveSuffixIcon = widget.isPassword
        ? IconButton(
            icon: AppSvgIcon(
              _obscure
                  ? AssetsConstants.passwordVisibleIcon
                  : AssetsConstants.passwordHideIcon,
              size: ThemeConstants.iconM,
              color: cs.onSurfaceVariant,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          )
        : widget.suffixIcon;

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: ThemeConstants.spaceS,
      children: [
        // ── Label above field ─────────────────────────────────────────────
        if (widget.labelText != null)
          AppText(
            widget.labelText!,
            isRequired: widget.isRequired,
            style: context.tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),

        // ── Field ─────────────────────────────────────────────────────────
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          obscureText: _obscure,
          keyboardType: effectiveKeyboardType,
          validator: widget.validator,
          inputFormatters: effectiveFormatters,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          buildCounter: widget.maxLength == null
              ? null
              : (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          onChanged: widget.onChanged,
          textCapitalization: widget.textCapitalization,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          autovalidateMode: widget.autovalidateMode,
          cursorColor: widget.cursorColor,
          style:
              widget.style ??
              context.tt.bodyMedium?.copyWith(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: effectiveHint,
            prefixIcon: effectivePrefixIcon,
            prefixIconConstraints:
                widget.prefixIconConstraints ??
                (widget.isMobileField
                    ? const BoxConstraints(minWidth: 0, minHeight: 0)
                    : null),
            suffixIcon: effectiveSuffixIcon,
            suffixIconConstraints: widget.suffixIconConstraints,
            hintStyle:
                widget.hintStyle ??
                context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            isDense: widget.isDense,
            filled: widget.filled,
            fillColor: widget.filled ? cs.surface : null,
            contentPadding:
                widget.contentPadding ??
                const EdgeInsetsDirectional.symmetric(
                  horizontal: ThemeConstants.paddingL,
                  vertical: ThemeConstants.paddingL,
                ),
            border: widget.border ?? borders.border,
            enabledBorder: widget.border ?? borders.enabledBorder,
            focusedBorder: widget.border ?? borders.focusedBorder,
            errorBorder: widget.border ?? borders.errorBorder,
            focusedErrorBorder: widget.border ?? borders.focusedErrorBorder,
          ),
        ),
      ],
    );
  }
}

class _MobilePrefix extends StatelessWidget {
  final ColorScheme colorScheme;

  const _MobilePrefix({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      children: [
        AppSpacing.w14,
        AppSvgIcon(
          AssetsConstants.arrowDownIcon,
          size: ThemeConstants.iconS,
          color: colorScheme.onSurfaceVariant,
        ),
        AppSpacing.w6,
        Container(width: 1, height: 22, color: colorScheme.outline),
        AppSpacing.w4,
      ],
    );
  }
}
