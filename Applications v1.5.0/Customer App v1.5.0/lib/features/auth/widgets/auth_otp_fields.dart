import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:customer/utils/extensions/context_extensions.dart';

class AuthOtpFields extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  const AuthOtpFields({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 60,
      textStyle: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.r12,
        border: Border.all(color: context.cs.outline, width: 1.2),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: AppDecorations.box(
        color: context.cs.primary.withValues(alpha: 0.06),
        borderRadius: AppRadius.r12,
        border: Border.all(color: context.cs.primary, width: 2),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      textStyle: context.tt.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: context.cs.primary,
      ),
      decoration: AppDecorations.box(
        color: context.cs.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.r12,
        border: Border.all(color: context.cs.primary, width: 1.5),
      ),
    );

    return Pinput(
      length: 6,
      controller: controller,
      focusNode: focusNode,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: focusedPinTheme,
      submittedPinTheme: submittedPinTheme,
      onChanged: onChanged,
      onCompleted: onCompleted,
    );
  }
}
