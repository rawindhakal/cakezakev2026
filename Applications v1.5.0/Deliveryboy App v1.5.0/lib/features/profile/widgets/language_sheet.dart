import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'dart:io';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';

import '../../../commons/widgets/app_text.dart';

import 'package:deliveryboy/commons/widgets/app_radio_option_tile.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/cubit/language_cubit.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/cubit/language_select_cubit.dart';
import 'package:deliveryboy/core/localization/models/language_model.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/local_storage/settings_hive_box.dart';
import 'package:deliveryboy/features/auth/cubit/update_fcm_token_cubit.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';

/// Opens the bottom sheet for selecting the app's display language.
void showLanguageSheet(BuildContext context) {
  final selectCubit = LanguageSelectCubit();

  showAppBottomSheet(
    context,
    title: context.translate(LanguageLabelKeys.selectLanguage),
    insetBottomSafeArea: false,
    padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingM, ThemeConstants.paddingL, 0),
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<LanguageCubit>()),
        BlocProvider.value(value: selectCubit),
      ],
      child: const _LanguageSheet(),
    ),
  ).whenComplete(selectCubit.close);
}

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet();

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  String? _pendingId;

  @override
  Widget build(BuildContext context) {
    return BlocListener<UpdateFcmTokenCubit, UpdateFcmTokenState>(
      listener: (context, state) {
        if (state is UpdateFcmTokenLoaded) AppNavigator.pop(context);
      },
      child: BlocConsumer<LanguageSelectCubit, LanguageSelectState>(
        listener: (context, selectState) {
          if (selectState is LanguageSelectLoaded) {
            context.read<LanguageCubit>().updateSelectedId(
              selectState.language.id ?? '',
            );
            SettingsHiveBox.instance.setLanguageId(
              selectState.language.id ?? '',
            );
            SettingsHiveBox.instance.setLanguageCode(
              selectState.language.code ?? '',
            );
            SettingsHiveBox.instance.setLanguageType(
              selectState.language.type ?? '',
            );
            SettingsHiveBox.instance.setLanguageUserSelected(true);
            context.read<UpdateFcmTokenCubit>().updateFcmToken(
              fcmToken: AuthHiveBox.instance.fcmToken,
              platform: Platform.isAndroid
                  ? ApiParameters.android
                  : ApiParameters.ios,
              languageId: selectState.language.adminLangIdForFcm ?? '',
            );
          }
        },
        builder: (context, selectState) {
          final isSelecting = selectState is LanguageSelecting;
          return BlocBuilder<LanguageCubit, LanguageState>(
            builder: (context, state) {
              final languages = state is LanguageLoaded
                  ? state.languages
                  : <LanguageJsonData>[];
              final selectedId = state is LanguageLoaded
                  ? state.selectedId
                  : null;

              final showingList =
                  state is! LanguageLoading &&
                  state is! LanguageError &&
                  selectState is! LanguageSelectError &&
                  languages.isNotEmpty;

              return Column(
                mainAxisSize: .min,
                children: [
                  if (state is LanguageLoading)
                    const ShimmerRows(count: 4)
                  else if (state is LanguageError)
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        vertical: ThemeConstants.paddingL,
                      ),
                      child: Column(
                        spacing: ThemeConstants.spaceM,
                        children: [
                          AppText(
                            state.message,
                            style: context.tt.headlineLarge?.copyWith(
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                context.read<LanguageCubit>().loadLanguages(),
                            icon: AppSvgIcon(
                              AssetsConstants.refreshIcon,
                              size: ThemeConstants.iconM,
                              color: context.cs.onSurfaceVariant,
                            ),
                            label: AppText(
                              context.translate(LanguageLabelKeys.retry),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (selectState is LanguageSelectError)
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        vertical: ThemeConstants.paddingL,
                      ),
                      child: AppText(
                        selectState.message,
                        style: context.tt.headlineLarge?.copyWith(
                          color: context.cs.error,
                        ),
                      ),
                    )
                  else if (languages.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: context.screenHeight * 0.5,
                      ),
                      child: RadioGroup<String>(
                        groupValue: selectedId,
                        onChanged: (id) {
                          if (!isSelecting) {
                            setState(() => _pendingId = id);
                            context.read<LanguageSelectCubit>().selectLanguage(
                              id ?? '',
                            );
                          }
                        },
                        child: SlideAnimationScope(
                          builder: (context, animationController) =>
                              ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsetsDirectional.only(
                                  bottom:
                                      context.bottomSafePadding +
                                      ThemeConstants.paddingL,
                                ),
                                itemCount: languages.length,
                                itemBuilder: (context, index) {
                                  final lang = languages[index];
                                  return SlideAnimation(
                                    position: index,
                                    slideDirection: SlideDirection.fromBottom,
                                    itemCount: languages.length,
                                    animationController: animationController,
                                    child: AppRadioOptionTile<String>(
                                      value: lang.id ?? '',
                                      title: lang.name ?? '—',
                                      subtitle: (lang.code ?? '').toUpperCase(),
                                      selected: selectedId == lang.id,
                                      enabled: !isSelecting,
                                      trailing:
                                          isSelecting && _pendingId == lang.id
                                          ? ShimmerInline(size: ThemeConstants.loaderSizeS)
                                          : null,
                                      onTap: () {
                                        setState(() => _pendingId = lang.id);
                                        context
                                            .read<LanguageSelectCubit>()
                                            .selectLanguage(lang.id ?? '');
                                      },
                                    ),
                                  );
                                },
                              ),
                        ),
                      ),
                    ),
                  if (!showingList)
                    SizedBox(
                      height:
                          context.bottomSafePadding + ThemeConstants.paddingL,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
