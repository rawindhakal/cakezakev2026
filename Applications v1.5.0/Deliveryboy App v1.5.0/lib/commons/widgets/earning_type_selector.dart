import 'package:deliveryboy/commons/models/earning_type.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../../core/theme/app_radius.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

class EarningTypeSelector extends StatelessWidget {
  final EarningType value;
  final ValueChanged<EarningType?> onChanged;
  final bool enabled;

  const EarningTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: RadioGroup<EarningType>(
        groupValue: value,
        onChanged: onChanged,
        child: Container(
          decoration: AppDecorations.card(
            color: context.cs.surface,
            borderRadius: AppRadius.r10,
            border: Border.all(color: context.cs.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: _EarningRadioTile(
                  label: context.translate(LanguageLabelKeys.salaried),
                  value: EarningType.salaried,
                ),
              ),
              Container(
                width: 1,
                height: context.screenHeight * 0.049,
                color: context.cs.outline,
              ),
              Expanded(
                child: _EarningRadioTile(
                  label: context.translate(LanguageLabelKeys.commission),
                  value: EarningType.commission,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarningRadioTile extends StatelessWidget {
  final String label;
  final EarningType value;

  const _EarningRadioTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final registry = RadioGroup.maybeOf<EarningType>(context);
    final isSelected = registry?.groupValue == value;

    return InkWell(
      onTap: () => registry?.onChanged(value),
      borderRadius: AppRadius.r10,
      child: Row(
        children: [
          Radio<EarningType>(
            value: value,
            activeColor: context.cs.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          AppText(
            label,
            style: context.tt.bodyMedium?.copyWith(
              color: isSelected ? context.cs.primary : context.cs.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
