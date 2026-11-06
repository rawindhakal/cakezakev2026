import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/promo_code/cubit/promo_code_validate_cubit.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PromoCodeInputRow extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onApply;

  const PromoCodeInputRow({
    super.key,
    required this.controller,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PromoCodeValidateCubit, PromoCodeValidateState>(
      builder: (context, validateState) {
        final isValidating =
            validateState is PromoCodeValidateLoading &&
            validateState.promoCode == controller.text.trim();
        return Row(
          spacing: ThemeConstants.spaceM,
          children: [
            Expanded(
              child: AppTextField(
                controller: controller,
                hintText: context.translate(LanguageLabelKeys.enterPromoCode),
                textCapitalization: TextCapitalization.characters,
                onFieldSubmitted: onApply,
              ),
            ),
            AppButton(
              label: context.translate(LanguageLabelKeys.apply),
              isLoading: isValidating,
              onPressed: isValidating ? null : () => onApply(controller.text),
              width: 80,
              height: 46,
            ),
          ],
        );
      },
    );
  }
}
