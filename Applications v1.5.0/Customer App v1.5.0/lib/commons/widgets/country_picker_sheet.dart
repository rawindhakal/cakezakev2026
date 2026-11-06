import 'package:customer/commons/widgets/api_country_phone_field.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_radio_option_tile.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/core/constants/theme_constants.dart';

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
      constraints: BoxConstraints(maxHeight: context.screenHeight * 0.75),
      child: Column(
        mainAxisSize: .min,
        children: [
          AppTextField(
            controller: _searchController,
            hintText: context.translate(LanguageLabelKeys.search),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ThemeConstants.paddingL,
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
            // No `border` override — the default outline set is what makes the
            // field visible against the sheet's surface-coloured background.
            contentPadding: const EdgeInsetsDirectional.symmetric(
              vertical: ThemeConstants.paddingS,
            ),
          ),
          AppSpacing.h12,
          Flexible(
            child: BlocBuilder<CountriesCubit, CountriesState>(
              builder: (context, state) {
                if (state is CountriesLoading || state is CountriesInitial) {
                  return const Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      vertical: ThemeConstants.paddingXXL,
                    ),
                    child: LoadingWidget(),
                  );
                }
                if (state is CountriesError) {
                  return Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      vertical: ThemeConstants.paddingL,
                    ),
                    child: AppText(
                      state.message,
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.error,
                        fontSize: 13,
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

                return RadioGroup<int?>(
                  groupValue: widget.selected?.id,
                  onChanged: (id) {
                    final country = countries.firstWhere(
                      (c) => c.id == id,
                      orElse: () => countries.first,
                    );
                    AppNavigator.pop(context, country);
                  },
                  child: SlideAnimationScope(
                    builder: (context, animationController) => ListView.builder(
                      shrinkWrap: true,
                      itemCount: countries.length,
                      itemBuilder: (context, index) {
                        final country = countries[index];
                        final isSelected = widget.selected?.id == country.id;
                        return SlideAnimation(
                          position: index,
                          itemCount: countries.length,
                          slideDirection: SlideDirection.fromBottom,
                          animationController: animationController,
                          child: AppRadioOptionTile<int?>(
                            value: country.id,
                            title: country.name ?? '',
                            subtitle: widget.showDialCode
                                ? formatDialCode(country.dialCode)
                                : null,
                            selected: isSelected,
                            margin: const EdgeInsetsDirectional.only(bottom: 2),
                            leading: ClipOval(
                              child: AppNetworkImage(
                                url: country.logoUrl ?? '',
                                width: 28,
                                height: 28,
                                errorWidget: AppSvgIcon(
                                  AssetsConstants.flagIcon,
                                  size: ThemeConstants.iconM,
                                  color: context.cs.onSurfaceVariant,
                                ),
                              ),
                            ),
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
