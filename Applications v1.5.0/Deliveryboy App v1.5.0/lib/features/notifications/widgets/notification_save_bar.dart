import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/notification_cubit.dart';
import '../cubit/notification_save_cubit.dart';
import '../models/notification_settings_model.dart';

/// Bottom bar with a save button for pending notification setting changes.
class NotificationSaveBar extends StatelessWidget {
  const NotificationSaveBar({super.key});

  void _save(BuildContext context) {
    final state = context.read<NotificationCubit>().state;
    if (state is! NotificationLoaded) return;
    final categories = state.data.data ?? [];
    final preferences = <Events>[
      for (final category in categories) ...?category.events,
    ];
    context.read<NotificationSaveCubit>().saveNotificationSettings(
      preferences: preferences,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, state) {
        if (state is NotificationLoaded &&
            (state.data.data?.isEmpty ?? true)) {
          return const SizedBox.shrink();
        }
        if (state is! NotificationLoaded) return const SizedBox.shrink();
        return BlocBuilder<NotificationSaveCubit, NotificationSaveState>(
          builder: (context, saveState) {
            final isLoading = saveState is NotificationSaveLoading;
            return Container(
              padding: EdgeInsetsDirectional.fromSTEB(
                ThemeConstants.paddingL,
                ThemeConstants.paddingM,
                ThemeConstants.paddingL,
                context.bottomSafePadding + 12,
              ),
              decoration: AppDecorations.card(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: context.cs.shadow,
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: AppButton(
                label: context.translate(LanguageLabelKeys.saveSettings),
                height: context.screenHeight * 0.062,
                isLoading: isLoading,
                onPressed: () => _save(context),
              ),
            );
          },
        );
      },
    );
  }
}
