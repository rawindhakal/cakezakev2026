import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/input_validators.dart';
import 'package:flutter/material.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';

/// Prompts for an email address (e.g. when a payment gateway requires one
/// but the user's profile has none) and resolves with the entered value,
/// or null if the sheet was dismissed.
Future<String?> showEmailInputSheet(
  BuildContext context, {
  String? initialEmail,
}) {
  return showAppBottomSheet<String>(
    context,
    title: context.translate(LanguageLabelKeys.enterEmail),
    builder: (sheetContext) => _EmailInputSheet(initialEmail: initialEmail),
  );
}

class _EmailInputSheet extends StatefulWidget {
  final String? initialEmail;
  const _EmailInputSheet({this.initialEmail});

  @override
  State<_EmailInputSheet> createState() => _EmailInputSheetState();
}

class _EmailInputSheetState extends State<_EmailInputSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    AppNavigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SlideAnimationList(
        crossAxisAlignment: .start,
        children: [
          AppTextField(
            controller: _controller,
            hintText: context.translate(LanguageLabelKeys.enterEmail),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) => v.validateEmail(context),
            onFieldSubmitted: (_) => _submit(),
          ),
          AppSpacing.h16,
          AppButton(
            label: context.translate(LanguageLabelKeys.confirm),
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
