import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/address/cubit/place_autocomplete_cubit.dart';
import 'package:customer/features/address/cubit/place_details_cubit.dart';
import 'package:customer/features/address/models/google_places_model.dart'
    hide Text;
import 'package:customer/features/address/widgets/location_suggestions.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Simple location search screen — user types a place, picks from suggestions.
/// Supports both Google Places and OSM via the unified server API.
/// Pops with [true] when location is saved to [SettingsHiveBox].
class LocationSearchScreen extends StatelessWidget {
  const LocationSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => PlaceAutocompleteCubit()),
        BlocProvider(create: (_) => PlaceDetailsCubit()),
      ],
      child: const _LocationSearchView(),
    );
  }
}

class _LocationSearchView extends StatefulWidget {
  const _LocationSearchView();

  @override
  State<_LocationSearchView> createState() => _LocationSearchViewState();
}

class _LocationSearchViewState extends State<_LocationSearchView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String v) => context.read<PlaceAutocompleteCubit>().search(v);

  void _onClear() {
    _controller.clear();
    context.read<PlaceAutocompleteCubit>().clear();
  }

  void _onTap(Suggestions suggestion) {
    final placeId = suggestion.placePrediction?.placeId ?? '';
    if (placeId.isEmpty) return;
    context.read<PlaceDetailsCubit>().fetchDetails(placeId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlaceDetailsCubit, PlaceDetailsState>(
      listener: (context, state) async {
        if (state is PlaceDetailsLoaded) {
          final d = state.details;
          final label = d.city.isNotEmpty
              ? d.city
              : d.formattedAddress.split(',').first.trim();
          await SettingsHiveBox.instance.saveUserLocation(
            latitude: d.latitude.toString(),
            longitude: d.longitude.toString(),
            label: label,
            address: d.formattedAddress,
            pincode: d.postalCode,
          );
          if (context.mounted) AppNavigator.pop(context, true);
        } else if (state is PlaceDetailsError) {
          if (context.mounted) {
            AppSnackBar.show(
              context: context,
              message: state.message,
              type: SnackBarType.error,
            );
          }
        }
      },
      child: AppScaffold(
        appBar: CustomAppBar(
          title: context.translate(LanguageLabelKeys.searchLocation),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ThemeConstants.paddingL,
                ThemeConstants.paddingM,
                ThemeConstants.paddingL,
                ThemeConstants.paddingS,
              ),
              child: AppTextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                onChanged: _onSearch,
                hintText: context.translate(
                  LanguageLabelKeys.searchAreaCityLandmark,
                ),
                prefixIcon: AppSvgIcon(
                  AssetsConstants.searchIcon,
                  size: ThemeConstants.iconS,
                  color: context.cs.onSurfaceVariant,
                  fit: BoxFit.scaleDown,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (_, value, _) => value.text.isNotEmpty
                      ? IconButton(
                          icon: AppSvgIcon(
                            AssetsConstants.closeIcon,
                            size: ThemeConstants.iconS,
                            color: context.cs.onSurfaceVariant,
                          ),
                          onPressed: _onClear,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),

            Expanded(
              child: Stack(
                children: [
                  EmptyStateWidget(
                    imagePath: AssetsConstants.noSearchFound,
                    title: context.translate(
                      LanguageLabelKeys.findYourLocation,
                    ),
                    subtitle: context.translate(
                      LanguageLabelKeys.findYourLocationSubtitle,
                    ),
                  ),
                  LocationSuggestions(onTap: _onTap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
