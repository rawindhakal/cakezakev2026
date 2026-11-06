import 'package:customer/commons/cubit/zones_cubit.dart';
import 'package:customer/commons/models/zones_model.dart';
import 'package:customer/commons/widgets/searchable_picker_list.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the delivery-zone picker bottom sheet backed by the [ZonesCubit] of
/// the calling context and resolves with the zone the user selected (or null
/// on dismiss). Zone counterpart of `showCountryPickerSheet`.
Future<ZonesData?> showZonePickerSheet(
  BuildContext context, {
  ZonesData? selected,
}) {
  final zonesCubit = context.read<ZonesCubit>();
  return showAppBottomSheet<ZonesData>(
    context,
    title: context.translate(LanguageLabelKeys.deliveryZone),
    builder: (_) => BlocProvider.value(
      value: zonesCubit,
      child: _ZonePickerSheet(selected: selected),
    ),
  );
}

class _ZonePickerSheet extends StatelessWidget {
  final ZonesData? selected;
  const _ZonePickerSheet({this.selected});

  void _retry(BuildContext context) {
    final cubit = context.read<ZonesCubit>();
    final countryId = cubit.countryId;
    if (countryId != null) cubit.fetchZones(countryId, force: true);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: context.screenHeight * 0.75),
      child: BlocBuilder<ZonesCubit, ZonesState>(
        builder: (context, state) => switch (state) {
          ZonesInitial() || ZonesLoading() => const PickerLoadingView(),
          ZonesError(:final message) => PickerErrorView(
            message: message,
            fallbackMessage: context.translate(
              LanguageLabelKeys.failedToLoadZones,
            ),
            onRetry: () => _retry(context),
          ),
          ZonesLoaded(:final zones) => SearchablePickerList<ZonesData>(
            items: zones,
            idOf: (e) => e.id,
            nameOf: (e) => e.name,
            selectedId: selected?.id,
            emptyMessage: context.translate(LanguageLabelKeys.noZonesFound),
          ),
        },
      ),
    );
  }
}
