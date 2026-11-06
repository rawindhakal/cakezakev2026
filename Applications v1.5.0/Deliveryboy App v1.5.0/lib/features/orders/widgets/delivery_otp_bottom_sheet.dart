import 'package:deliveryboy/commons/utils/app_haptics.dart';
import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:flutter/services.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Prompts the delivery boy for the customer's delivery OTP and only returns
/// the entered OTP (via `AppNavigator.pop`) once it matches [expectedOtp].
/// Callers must show this before calling the status-update API for the
/// "Delivered" status when the order carries a non-zero OTP, and forward the
/// returned OTP to that API call. Orders with a null or 0 OTP skip this sheet
/// and update the status directly.
Future<String?> showDeliveryOtpBottomSheet({
  required BuildContext context,
  required int? expectedOtp,
}) {
  return showAppBottomSheet<String>(
    context,
    padding: null,
    showDragHandle: false,
    builder: (ctx) => DeliveryOtpBottomSheet(expectedOtp: expectedOtp),
  );
}

/// Bottom sheet body for [showDeliveryOtpBottomSheet] — collects and validates
/// the OTP against [expectedOtp].
class DeliveryOtpBottomSheet extends StatefulWidget {
  final int? expectedOtp;
  const DeliveryOtpBottomSheet({super.key, required this.expectedOtp});

  @override
  State<DeliveryOtpBottomSheet> createState() => _DeliveryOtpBottomSheetState();
}

class _DeliveryOtpBottomSheetState extends State<DeliveryOtpBottomSheet> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matchesExpected(String value) {
    final entered = int.tryParse(value);
    return entered != null &&
        widget.expectedOtp != null &&
        entered == widget.expectedOtp;
  }

  void _onChanged(String value) {
    final expectedLength = widget.expectedOtp?.toString().length ?? 0;
    if (value.length < expectedLength) {
      if (_errorText != null) setState(() => _errorText = null);
      return;
    }
    final matches = _matchesExpected(value);
    if (matches) {
      AppHaptics.success();
    } else {
      AppHaptics.error();
    }
    setState(() {
      _errorText = matches
          ? null
          : context.translate(LanguageLabelKeys.invalidOtp);
    });
  }

  void _submit() {
    if (_matchesExpected(_controller.text.trim())) {
      AppNavigator.pop(context, _controller.text.trim());
      return;
    }
    AppHaptics.error();
    setState(
      () => _errorText = context.translate(LanguageLabelKeys.invalidOtp),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: ThemeConstants.paddingL,
        end: ThemeConstants.paddingL,
        top: ThemeConstants.paddingXL,
        bottom:
            context.keyboardInset +
            20 +
            context.bottomSafePadding,
      ),
      child: SlideAnimationList(
        crossAxisAlignment: .start,
        children: [
          Center(
            child: Container(
              width: context.screenWidth * 0.107,
              height: context.screenHeight * 0.005,
              decoration: AppDecorations.card(
                color: context.cs.outlineVariant,
                borderRadius: AppRadius.r12,
              ),
            ),
          ),
          AppSpacing.h16,
          AppText(
            context.translate(LanguageLabelKeys.enterDeliveryOtp),
            style: context.tt.titleMedium,
          ),
          AppSpacing.h4,
          AppText(
            context.translate(LanguageLabelKeys.enterOtpSharedByCustomer),
            style: context.tt.bodySmall?.copyWith(
              color: context.cs.onSurfaceVariant,
            ),
          ),
          AppSpacing.h16,
          AppTextField(
            controller: _controller,
            hintText: context.translate(LanguageLabelKeys.deliveryOtp),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: _onChanged,
          ),
          if (_errorText != null) ...[
            AppSpacing.h8,
            AppText(
              _errorText!,
              style: context.tt.bodySmall?.copyWith(color: context.cs.error),
            ),
          ],
          AppSpacing.h20,
          Row(
            spacing: ThemeConstants.spaceM,
            children: [
              Expanded(
                child: AppButton(
                  label: context.translate(LanguageLabelKeys.cancel),
                  variant: .outline,
                  onPressed: () => AppNavigator.pop(context),
                ),
              ),
              Expanded(
                child: AppButton(
                  label: context.translate(LanguageLabelKeys.submit),
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
