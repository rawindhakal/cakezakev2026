import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';

import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/features/address/cubit/place_autocomplete_cubit.dart';
import 'package:customer/features/address/models/google_places_model.dart'
    hide Text;
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/constants/theme_constants.dart';

class LocationSuggestions extends StatelessWidget {
  final void Function(Suggestions) onTap;

  const LocationSuggestions({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaceAutocompleteCubit, PlaceAutocompleteState>(
      builder: (context, state) {
        if (state is PlaceAutocompleteLoaded && state.suggestions.isNotEmpty) {
          final tiles = state.suggestions.map((s) {
            final pred = s.placePrediction;
            final main =
                pred?.structuredFormat?.mainText?.text ??
                pred?.text?.text ??
                '';
            final secondary = pred?.structuredFormat?.secondaryText?.text ?? '';
            return _tile(
              context,
              main: main,
              secondary: secondary,
              onTap: () => onTap(s),
            );
          }).toList();
          return _container(context, tiles);
        }
        return AppSpacing.shrink;
      },
    );
  }

  Widget _container(BuildContext context, List<Widget> tiles) {
    return Container(
      margin: const EdgeInsetsDirectional.only(
        top: ThemeConstants.paddingS,
        start: ThemeConstants.paddingL,
        end: ThemeConstants.paddingL,
      ),
      decoration: AppDecorations.outlinedCard(
        color: context.cs.surface,
        borderColor: context.cs.outline,
        boxShadow: [
          BoxShadow(
            color: context.cs.scrim.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.r10,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: ThemeConstants.paddingXS,
            ),
            shrinkWrap: true,
            itemCount: tiles.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 58,
              color: context.cs.outline.withValues(alpha: 0.5),
            ),
            itemBuilder: (_, i) => tiles[i],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required String main,
    required String secondary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingM,
          vertical: ThemeConstants.paddingS,
        ),
        child: Row(
          spacing: ThemeConstants.spaceM,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: AppDecorations.primaryIconBox(
                color: context.cs.primary.withValues(alpha: 0.08),
                borderRadius: 8,
              ),
              child: AppSvgIcon(
                AssetsConstants.addressIcon,
                size: ThemeConstants.iconS,
                color: context.cs.primary,
                fit: BoxFit.scaleDown,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  AppText(
                    main,
                    style: context.tt.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                  if (secondary.isNotEmpty)
                    AppText(
                      secondary,
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
