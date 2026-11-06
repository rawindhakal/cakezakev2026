import 'package:customer/commons/cubit/regions_cubit.dart';
import 'package:customer/commons/models/regions_model.dart';
import 'package:customer/commons/widgets/searchable_picker_list.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the state/region picker bottom sheet backed by the [RegionsCubit] of
/// the calling context and resolves with the region the user selected (or
/// null on dismiss). Region counterpart of `showZonePickerSheet`.
Future<RegionsData?> showRegionPickerSheet(
  BuildContext context, {
  RegionsData? selected,
}) {
  final regionsCubit = context.read<RegionsCubit>();
  return showAppBottomSheet<RegionsData>(
    context,
    title: context.translate(LanguageLabelKeys.stateLabel),
    builder: (_) => BlocProvider.value(
      value: regionsCubit,
      child: _RegionPickerSheet(selected: selected),
    ),
  );
}

class _RegionPickerSheet extends StatelessWidget {
  final RegionsData? selected;
  const _RegionPickerSheet({this.selected});

  void _retry(BuildContext context) {
    final cubit = context.read<RegionsCubit>();
    final countryId = cubit.countryId;
    if (countryId != null) cubit.fetchRegions(countryId, force: true);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: context.screenHeight * 0.75),
      child: BlocBuilder<RegionsCubit, RegionsState>(
        builder: (context, state) => switch (state) {
          RegionsInitial() || RegionsLoading() => const PickerLoadingView(),
          RegionsError(:final message) => PickerErrorView(
            message: message,
            fallbackMessage: context.translate(
              LanguageLabelKeys.failedToLoadRegions,
            ),
            onRetry: () => _retry(context),
          ),
          RegionsLoaded(:final regions) => SearchablePickerList<RegionsData>(
            items: regions,
            idOf: (e) => e.id,
            nameOf: (e) => e.name,
            selectedId: selected?.id,
            emptyMessage: context.translate(LanguageLabelKeys.noRegionsFound),
          ),
        },
      ),
    );
  }
}
