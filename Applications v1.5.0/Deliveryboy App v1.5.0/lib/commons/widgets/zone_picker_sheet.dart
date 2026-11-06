import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/commons/cubit/zones_cubit.dart';
import 'package:deliveryboy/commons/models/zones_model.dart';
import 'package:deliveryboy/commons/widgets/app_radio_option_tile.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the shared zone picker bottom sheet backed by [ZonesCubit] and
/// resolves with the zone the user selected (or null on dismiss).
Future<ZonesData?> showZonePickerSheet(
  BuildContext context, {
  ZonesData? selected,
}) {
  return showAppBottomSheet<ZonesData>(
    context,
    title: context.translate(LanguageLabelKeys.zone),
    builder: (sheetContext) => BlocProvider.value(
      value: context.read<ZonesCubit>(),
      child: _ZonePickerSheet(selected: selected),
    ),
  );
}

class _ZonePickerSheet extends StatefulWidget {
  final ZonesData? selected;
  const _ZonePickerSheet({this.selected});

  @override
  State<_ZonePickerSheet> createState() => _ZonePickerSheetState();
}

class _ZonePickerSheetState extends State<_ZonePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: context.screenHeight * 0.75),
      child: Column(
        mainAxisSize: .min,
        children: [
          AppTextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            hintText: context.translate(LanguageLabelKeys.search),
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ThemeConstants.paddingM,
                end: ThemeConstants.paddingS,
              ),
              child: AppSvgIcon(
                AssetsConstants.searchIcon,
                size: ThemeConstants.iconS,
                color: context.cs.onSurfaceVariant,
                fit: BoxFit.scaleDown,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
          ),
          AppSpacing.h12,
          Flexible(
            child: BlocBuilder<ZonesCubit, ZonesState>(
              builder: (context, state) {
                if (state is ZonesLoading || state is ZonesInitial) {
                  return const ShimmerRows(count: 5);
                }
                if (state is ZonesError) {
                  return Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      vertical: ThemeConstants.paddingL,
                    ),
                    child: AppText(
                      state.message,
                      style: context.tt.headlineLarge?.copyWith(
                        color: context.cs.error,
                      ),
                    ),
                  );
                }
                final zones = (state as ZonesLoaded).zones.where((z) {
                  if (_query.isEmpty) return true;
                  return (z.name ?? '').toLowerCase().contains(_query);
                }).toList();

                if (zones.isEmpty) {
                  return Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      vertical: ThemeConstants.paddingXXL,
                    ),
                    child: AppText(
                      context.translate(LanguageLabelKeys.noZonesFound),
                      style: context.tt.bodyMedium?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return RadioGroup<int>(
                  groupValue: widget.selected?.id,
                  onChanged: (id) {
                    final match = zones.where((z) => z.id == id).toList();
                    if (match.isNotEmpty) {
                      AppNavigator.pop(context, match.first);
                    }
                  },
                  child: SlideAnimationScope(
                    builder: (context, animationController) => ListView.builder(
                      shrinkWrap: true,
                      itemCount: zones.length,
                      itemBuilder: (context, index) {
                        final zone = zones[index];
                        return SlideAnimation(
                          position: index,
                          slideDirection: SlideDirection.fromBottom,
                          itemCount: zones.length,
                          animationController: animationController,
                          child: AppRadioOptionTile<int>(
                            value: zone.id ?? -1,
                            title: zone.name ?? '',
                            selected: widget.selected?.id == zone.id,
                            onTap: () => AppNavigator.pop(context, zone),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
