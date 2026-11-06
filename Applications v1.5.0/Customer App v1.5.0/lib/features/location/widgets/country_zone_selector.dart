import 'dart:async';

import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/cubit/zones_cubit.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/commons/models/zones_model.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/country_dropdown_field.dart';
import 'package:customer/commons/widgets/zone_dropdown_field.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/location/screens/zone_location_picker_screen.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Country + delivery-zone picker shown on the location setup screens.
/// Auto-selects the user's last-picked country (if still present in the
/// list), else the one flagged `is_default` (falls back to the first one),
/// as soon as [CountriesCubit] has data, then — unless [autoSelectZone] is
/// false — loads that country's zones into the zone dropdown and
/// pre-selects the first of them — reloading and re-selecting whenever the
/// country changes. Picking a zone (or re-picking the pre-selected one)
/// opens [ZoneLocationPickerScreen] to pin-drop within it;
/// [onLocationConfirmed] fires once that screen saves a location and pops, so
/// the caller can close the sheet / navigate home the same way the
/// search-manually flow does.
class CountryZoneSelector extends StatefulWidget {
  final VoidCallback? onLocationConfirmed;
  // False on the first-run "no location" screen — the very first zone
  // pick there should always be a deliberate, hand-made choice.
  final bool autoSelectZone;

  const CountryZoneSelector({
    super.key,
    this.onLocationConfirmed,
    this.autoSelectZone = true,
  });

  @override
  State<CountryZoneSelector> createState() => _CountryZoneSelectorState();
}

class _CountryZoneSelectorState extends State<CountryZoneSelector> {
  late final ZonesCubit _zonesCubit = ZonesCubit();
  CountriesData? _selectedCountry;
  ZonesData? _selectedZone;
  // Only true for the sheet's initial country pick — a user-driven country
  // switch within the same sheet session must never auto-fill the zone, it
  // has to be picked by hand again.
  bool _allowAutoZone = false;

  @override
  void initState() {
    super.initState();
    // Countries may already be loaded (globally fetched on app start) — a
    // BlocListener only fires on *future* transitions, so check once here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeSelectDefault(context.read<CountriesCubit>().state);
    });
  }

  @override
  void dispose() {
    _zonesCubit.close();
    super.dispose();
  }

  void _maybeSelectDefault(CountriesState state) {
    if (_selectedCountry != null) return;
    if (state is! CountriesLoaded || state.countries.isEmpty) return;
    final lastCountryId = SettingsHiveBox.instance.selectedCountryId;
    CountriesData? lastCountry;
    if (lastCountryId != null) {
      for (final c in state.countries) {
        if (c.id == lastCountryId) {
          lastCountry = c;
          break;
        }
      }
    }
    final defaultCountry =
        lastCountry ??
        state.countries.firstWhere(
          (c) => c.isDefault == 1,
          orElse: () => state.countries.first,
        );
    _selectCountry(defaultCountry, allowAutoZone: widget.autoSelectZone);
  }

  /// [allowAutoZone] is true only for the sheet's own initial pick (default
  /// or last-used country) — a country the user picks by hand from the
  /// dropdown always leaves the zone for them to pick by hand too.
  void _selectCountry(CountriesData country, {bool allowAutoZone = false}) {
    if (_selectedCountry?.id == country.id) return;
    setState(() {
      _selectedCountry = country;
      _selectedZone = null;
    });
    _allowAutoZone = allowAutoZone;
    unawaited(SettingsHiveBox.instance.saveSelectedCountryId(country.id));
    if (country.id != null) _zonesCubit.fetchZones(country.id!);
  }

  void _maybeSelectDefaultZone(ZonesState state) {
    if (!_allowAutoZone) return;
    if (_selectedZone != null) return;
    if (state is! ZonesLoaded || state.zones.isEmpty) return;
    _allowAutoZone = false;
    final lastZoneId = SettingsHiveBox.instance.zoneId;
    final defaultZone = state.zones.firstWhere(
      (z) => z.id == lastZoneId,
      orElse: () => state.zones.first,
    );
    // Only the display default — no navigation/save until the user actually
    // taps a zone, same as the country field pre-fill.
    setState(() => _selectedZone = defaultZone);
  }

  Future<void> _selectZone(ZonesData zone) async {
    // No session write here — ZoneLocationPickerScreen saves the zone only
    // once its point is validated, so backing out leaves the session intact.
    setState(() => _selectedZone = zone);
    final confirmed = await AppNavigator.push<bool>(
      context,
      ZoneLocationPickerScreen(zone: zone),
    );
    if (confirmed == true) widget.onLocationConfirmed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _zonesCubit,
      child: MultiBlocListener(
        listeners: [
          BlocListener<CountriesCubit, CountriesState>(
            listener: (context, state) => _maybeSelectDefault(state),
          ),
          BlocListener<ZonesCubit, ZonesState>(
            listener: (context, state) => _maybeSelectDefaultZone(state),
          ),
        ],
        child: BlocBuilder<CountriesCubit, CountriesState>(
          builder: (context, countriesState) {
            // A lone country is not a choice — drop its field and let the
            // zone one carry the whole selection.
            final showCountry =
                countriesState is! CountriesLoaded ||
                countriesState.countries.length > 1;
            return BlocBuilder<ZonesCubit, ZonesState>(
              builder: (context, zonesState) {
                // Only drop the zone field once we know there is nothing to
                // pick — while loading/erroring it still has something to say.
                final showZone =
                    zonesState is! ZonesLoaded || zonesState.zones.isNotEmpty;
                // Neither field left: the whole block, heading included, is
                // dead weight on the sheet.
                if (!showCountry && !showZone) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    // Separates the pickers from the detect/search buttons
                    // both hosts place above us. Lives inside the block so it
                    // disappears along with everything else.
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: context.cs.outlineVariant),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: ThemeConstants.paddingM,
                          ),
                          child: AppText(
                            context.translate(LanguageLabelKeys.or),
                            style: context.tt.bodySmall?.copyWith(
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: context.cs.outlineVariant),
                        ),
                      ],
                    ),
                    AppSpacing.h20,
                    const _Heading(),
                    AppSpacing.h14,
                    if (showCountry) ...[
                      CountryDropdownField(
                        selected: _selectedCountry,
                        labelText: context.translate(LanguageLabelKeys.country),
                        hintText: context.translate(
                          LanguageLabelKeys.enterCountry,
                        ),
                        onChanged: _selectCountry,
                      ),
                      AppSpacing.h16,
                    ],
                    if (showZone)
                      ZoneDropdownField(
                        selected: _selectedZone,
                        labelText: context.translate(
                          LanguageLabelKeys.deliveryZone,
                        ),
                        hintText: context.translate(
                          LanguageLabelKeys.selectYourZone,
                        ),
                        onChanged: _selectZone,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Pin badge + left-aligned title/subtitle introducing the two pickers. The
/// badge stays pinned to the first text line, so it does not drift down when
/// the subtitle wraps onto a second one.
class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: .start,
      children: [
        Container(
          width: 40,
          height: 40,
          padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingS),
          decoration: AppDecorations.primaryIconBox(
            color: context.cs.primaryContainer,
          ),
          child: AppSvgIcon(
            AssetsConstants.addressIcon,
            size: ThemeConstants.iconM,
            color: context.cs.primary,
          ),
        ),
        AppSpacing.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              AppText(
                context.translate(LanguageLabelKeys.weDeliverToSelectLocations),
                style: context.tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurface,
                ),
              ),
              AppSpacing.h4,
              AppText(
                context.translate(
                  LanguageLabelKeys.chooseCountryAndZoneMessage,
                ),
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
