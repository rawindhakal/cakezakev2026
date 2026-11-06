import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Visual variants for [AppTextField].
/// [outlined] is the default form-field look. [plain] is borderless with no
/// fill, for use inside an already-decorated container (e.g. chat input pill).
/// Visual style of [AppTextField].
enum AppTextFieldVariant { outlined, plain }

/// Standard app text field with consistent border, label, and error styling.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
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
  final String? countryCode;
  final VoidCallback? onCountryTap;
  final AppTextFieldVariant variant;
  final EdgeInsetsGeometry? contentPadding;
  final BoxConstraints? prefixIconConstraints;
  final BoxConstraints? suffixIconConstraints;
  final AutovalidateMode autovalidateMode;
  final bool autofocus;

  const AppTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = '',
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
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
    this.countryCode,
    this.onCountryTap,
    this.variant = AppTextFieldVariant.outlined,
    this.contentPadding,
    this.prefixIconConstraints,
    this.suffixIconConstraints,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveKeyboardType = isMobileField
        ? TextInputType.phone
        : keyboardType;
    final effectiveFormatters = isMobileField
        ? [FilteringTextInputFormatter.digitsOnly]
        : (inputFormatters ?? []);
    final effectiveHint = isMobileField
        ? context.translate(LanguageLabelKeys.enterMobileNumber)
        : hintText;
    final effectivePrefixIcon = isMobileField
        ? _MobilePrefix(countryCode: countryCode, onTap: onCountryTap)
        : prefixIcon;
    final isPlain = variant == AppTextFieldVariant.plain;
    final borders = AppDecorations.inputBorderSet(context.cs);

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscureText,
      keyboardType: effectiveKeyboardType,
      textInputAction: textInputAction,
      validator: validator,
      autovalidateMode: autovalidateMode,
      inputFormatters: effectiveFormatters,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      buildCounter: maxLength == null
          ? null
          : (
              context, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      cursorColor: context.cs.onSurface,
      style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurface),
      decoration: InputDecoration(
        hintText: effectiveHint,
        labelText: labelText,
        prefixIcon: effectivePrefixIcon,
        prefixIconConstraints:
            prefixIconConstraints ??
            (isMobileField
                ? const BoxConstraints(minWidth: 0, minHeight: 0)
                : null),
        suffixIcon: suffixIcon,
        suffixIconConstraints: suffixIconConstraints,
        hintStyle: context.tt.bodyMedium?.copyWith(
          color: context.cs.onSurfaceVariant,
        ),
        filled: !isPlain,
        fillColor: context.cs.surface,
        isDense: isPlain,
        contentPadding:
            contentPadding ??
            (isPlain
                ? const EdgeInsetsDirectional.symmetric(vertical: 13)
                : const EdgeInsetsDirectional.symmetric(
                    horizontal: ThemeConstants.paddingL,
                    vertical: 15,
                  )),
        border: isPlain ? InputBorder.none : borders.border,
        enabledBorder: isPlain ? InputBorder.none : borders.enabledBorder,
        focusedBorder: isPlain ? InputBorder.none : borders.focusedBorder,
        errorBorder: isPlain ? InputBorder.none : borders.errorBorder,
        focusedErrorBorder: isPlain
            ? InputBorder.none
            : borders.focusedErrorBorder,
      ),
    );
  }
}

class _MobilePrefix extends StatelessWidget {
  final String? countryCode;
  final VoidCallback? onTap;

  const _MobilePrefix({this.countryCode, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: .min,
        children: [
          AppSpacing.w14,
          AppText(
            countryCode ?? "",
            style: context.tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: context.cs.onSurface,
            ),
          ),
          AppSpacing.w4,
          AppSvgIcon(
            AssetsConstants.arrowDownIcon,
            size: ThemeConstants.iconS,
            color: context.cs.onSurfaceVariant,
          ),
          AppSpacing.w6,
          Container(
            width: 1,
            height: context.screenHeight * 0.027,
            color: context.cs.outline,
          ),
          AppSpacing.w4,
        ],
      ),
    );
  }
}
