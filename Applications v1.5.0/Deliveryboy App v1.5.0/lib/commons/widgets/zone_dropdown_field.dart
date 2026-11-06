import 'package:deliveryboy/commons/models/zones_model.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/commons/widgets/zone_picker_sheet.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Read-only "Zone" select field — opens [showZonePickerSheet] and reports the
/// chosen zone back via [onChanged]. The list shown is whatever the
/// `ZonesCubit` currently holds for the selected country.
class ZoneDropdownField extends StatelessWidget {
  final ZonesData? selected;
  final String labelText;
  final String hintText;
  final ValueChanged<ZonesData> onChanged;
  final String? Function(String?)? validator;
  final bool readOnly;

  const ZoneDropdownField({
    super.key,
    required this.selected,
    required this.labelText,
    required this.hintText,
    required this.onChanged,
    this.validator,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: selected?.name ?? '');
    return AppTextField(
      controller: controller,
      labelText: labelText,
      hintText: hintText,
      readOnly: true,
      validator: validator,
      suffixIcon: readOnly
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ThemeConstants.paddingS,
                end: ThemeConstants.paddingM,
              ),
              child: AppSvgIcon(
                AssetsConstants.arrowDownIcon,
                size: ThemeConstants.iconS,
                color: context.cs.onSurfaceVariant,
              ),
            ),
      suffixIconConstraints: readOnly
          ? null
          : const BoxConstraints(minWidth: 0, minHeight: 0),
      onTap: readOnly
          ? null
          : () async {
              final zone = await showZonePickerSheet(
                context,
                selected: selected,
              );
              if (zone != null) onChanged(zone);
            },
    );
  }
}
