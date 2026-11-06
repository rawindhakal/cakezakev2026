import 'package:customer/commons/cubit/regions_cubit.dart';
import 'package:customer/commons/models/regions_model.dart';
import 'package:customer/commons/widgets/app_select_field.dart';
import 'package:customer/commons/widgets/region_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Read-only "State" select field — opens [showRegionPickerSheet] and reports
/// the chosen region back via [onChanged]. Requires a [RegionsCubit] above it:
/// the field spins while that cubit loads and stays inert until a country
/// has been picked (i.e. while the cubit is still in its initial state).
class RegionDropdownField extends StatelessWidget {
  final RegionsData? selected;
  final String labelText;
  final String hintText;
  final ValueChanged<RegionsData> onChanged;
  final String? Function(String?)? validator;
  final bool isRequired;

  const RegionDropdownField({
    super.key,
    required this.selected,
    required this.labelText,
    required this.hintText,
    required this.onChanged,
    this.validator,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RegionsCubit, RegionsState>(
      builder: (context, state) {
        final isLoading = state is RegionsLoading;
        return AppSelectField(
          value: selected?.name,
          labelText: labelText,
          hintText: hintText,
          isRequired: isRequired,
          validator: validator,
          isLoading: isLoading,
          onTap: isLoading || state is RegionsInitial
              ? null
              : () async {
                  final region = await showRegionPickerSheet(
                    context,
                    selected: selected,
                  );
                  // The sheet outlives a dismissal of whatever hosts this
                  // field — onChanged pushes a route / calls setState.
                  if (region != null && context.mounted) onChanged(region);
                },
        );
      },
    );
  }
}
