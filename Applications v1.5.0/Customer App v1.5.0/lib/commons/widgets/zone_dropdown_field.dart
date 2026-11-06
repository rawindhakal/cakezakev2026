import 'package:customer/commons/cubit/zones_cubit.dart';
import 'package:customer/commons/models/zones_model.dart';
import 'package:customer/commons/widgets/app_select_field.dart';
import 'package:customer/commons/widgets/zone_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Read-only "Delivery zone" select field — opens [showZonePickerSheet] and
/// reports the chosen zone back via [onChanged]. Requires a [ZonesCubit] above
/// it: the field spins while that cubit loads and stays inert until a country
/// has been picked (i.e. while the cubit is still in its initial state).
class ZoneDropdownField extends StatelessWidget {
  final ZonesData? selected;
  final String labelText;
  final String hintText;
  final ValueChanged<ZonesData> onChanged;
  final String? Function(String?)? validator;

  const ZoneDropdownField({
    super.key,
    required this.selected,
    required this.labelText,
    required this.hintText,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ZonesCubit, ZonesState>(
      builder: (context, state) {
        final isLoading = state is ZonesLoading;
        return AppSelectField(
          value: selected?.name,
          labelText: labelText,
          hintText: hintText,
          validator: validator,
          isLoading: isLoading,
          onTap: isLoading || state is ZonesInitial
              ? null
              : () async {
                  final zone = await showZonePickerSheet(
                    context,
                    selected: selected,
                  );
                  // The sheet outlives a dismissal of whatever hosts this
                  // field — onChanged pushes a route / calls setState.
                  if (zone != null && context.mounted) onChanged(zone);
                },
        );
      },
    );
  }
}
