import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/commons/cubit/countries_cubit.dart';
import 'package:deliveryboy/commons/models/countries_model.dart';
import 'package:deliveryboy/commons/widgets/app_network_image.dart';
import 'package:deliveryboy/commons/widgets/app_radio_option_tile.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/commons/widgets/country_phone_field.dart';
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
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Opens the shared country picker bottom sheet backed by [CountriesCubit]
/// and resolves with the country the user selected (or null on dismiss).
Future<CountriesData?> showCountryPickerSheet(
  BuildContext context, {
  CountriesData? selected,
  bool showDialCode = false,
}) {
  return showAppBottomSheet<CountriesData>(
    context,
    title: context.translate(LanguageLabelKeys.country),
    builder: (sheetContext) => BlocProvider.value(
      value: context.read<CountriesCubit>(),
      child: _CountryPickerSheet(
        selected: selected,
        showDialCode: showDialCode,
      ),
    ),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  final CountriesData? selected;
  final bool showDialCode;
  const _CountryPickerSheet({this.selected, this.showDialCode = false});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
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
      constraints: BoxConstraints(maxHeight: context.heightFraction(0.75)),
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
                size: ThemeConstants.iconL,
                color: context.cs.onSurfaceVariant,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
          ),
          AppSpacing.h12,
          Flexible(
            child: BlocBuilder<CountriesCubit, CountriesState>(
              builder: (context, state) {
                if (state is CountriesLoading || state is CountriesInitial) {
                  return const ShimmerRows(count: 5);
                }
                if (state is CountriesError) {
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
                final countries = (state as CountriesLoaded).countries.where((
                  c,
                ) {
                  if (_query.isEmpty) return true;
                  return (c.name ?? '').toLowerCase().contains(_query) ||
                      (c.dialCode ?? '').toLowerCase().contains(_query);
                }).toList();

                return RadioGroup<int>(
                  groupValue: widget.selected?.id,
                  onChanged: (id) {
                    final match = countries.where((c) => c.id == id).toList();
                    if (match.isNotEmpty) {
                      AppNavigator.pop(context, match.first);
                    }
                  },
                  child: SlideAnimationScope(
                    builder: (context, animationController) => ListView.builder(
                      shrinkWrap: true,
                      itemCount: countries.length,
                      itemBuilder: (context, index) {
                        final country = countries[index];
                        return SlideAnimation(
                          position: index,
                          slideDirection: SlideDirection.fromBottom,
                          itemCount: countries.length,
                          animationController: animationController,
                          child: AppRadioOptionTile<int>(
                            value: country.id ?? -1,
                            title: country.name ?? '',
                            subtitle: widget.showDialCode
                                ? formatDialCode(country.dialCode)
                                : null,
                            leading: ClipOval(
                              child: AppNetworkImage(
                                url: country.logoUrl ?? '',
                                width: context.screenWidth * 0.075,
                                height: context.screenWidth * 0.075,
                                errorWidget: AppSvgIcon(
                                  AssetsConstants.flagIcon,
                                  size: ThemeConstants.iconM,
                                  color: context.cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            selected: widget.selected?.id == country.id,
                            onTap: () => AppNavigator.pop(context, country),
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
