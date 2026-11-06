import 'package:customer/commons/widgets/app_radio_option_tile.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/theme/cubit/theme_cubit.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/core/constants/theme_constants.dart';

void showAppearanceSheet(BuildContext context) {
  showAppBottomSheet(
    context,
    title: context.translate(LanguageLabelKeys.appearance),
    padding: const EdgeInsetsDirectional.fromSTEB(
      ThemeConstants.paddingL,
      ThemeConstants.paddingM,
      ThemeConstants.paddingL,
      ThemeConstants.spaceXXXL,
    ),
    builder: (_) => BlocProvider.value(
      value: context.read<ThemeCubit>(),
      child: const _AppearanceSheet(),
    ),
  );
}

class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, state) {
        final current = state.themeMode;
        final cubit = context.read<ThemeCubit>();

        void select(ThemeMode mode) {
          if (mode == ThemeMode.system) cubit.setSystem();
          if (mode == ThemeMode.light) cubit.setLight();
          if (mode == ThemeMode.dark) cubit.setDark();
          AppNavigator.pop(context);
        }

        final options = [
          AppRadioOptionTile<ThemeMode>(
            leading: AppSvgIcon(
              AssetsConstants.systemThemeIcon,
              size: ThemeConstants.iconM,
              color: context.cs.onSurfaceVariant,
            ),
            title: context.translate(LanguageLabelKeys.systemDefault),
            value: ThemeMode.system,
            selected: current == ThemeMode.system,
            highlightSelectedColor: false,
            onTap: () => select(ThemeMode.system),
          ),
          AppRadioOptionTile<ThemeMode>(
            leading: AppSvgIcon(
              AssetsConstants.lightThemeIcon,
              size: ThemeConstants.iconM,
              color: context.cs.onSurfaceVariant,
            ),
            title: context.translate(LanguageLabelKeys.light),
            value: ThemeMode.light,
            selected: current == ThemeMode.light,
            highlightSelectedColor: false,
            onTap: () => select(ThemeMode.light),
          ),
          AppRadioOptionTile<ThemeMode>(
            leading: AppSvgIcon(
              AssetsConstants.themeIcon,
              size: ThemeConstants.iconM,
              color: context.cs.onSurfaceVariant,
            ),
            title: context.translate(LanguageLabelKeys.dark),
            value: ThemeMode.dark,
            selected: current == ThemeMode.dark,
            highlightSelectedColor: false,
            onTap: () => select(ThemeMode.dark),
          ),
        ];

        return RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (mode) => select(mode ?? ThemeMode.system),
          child: SlideAnimationList(children: options),
        );
      },
    );
  }
}
