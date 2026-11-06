import 'dart:async';

import 'package:customer/commons/cubit/country_settings_cubit.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/features/spin_wheel/cubit/spin_wheel_rewards_cubit.dart';
import 'package:customer/features/spin_wheel/models/spin_wheel_model.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_dialog.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Wallet-won amount from the `rewards` API's `summary` block, plus a live
/// countdown to `spins.next_spin_at` (from the `spin_wheel` config API) once
/// today's spins are used up — sits above the reward history list.
class SpinWheelRewardsSummaryHeader extends StatefulWidget {
  final SpinRewardsSummary summary;
  final SpinInfo? spinInfo;

  const SpinWheelRewardsSummaryHeader({
    super.key,
    required this.summary,
    this.spinInfo,
  });

  @override
  State<SpinWheelRewardsSummaryHeader> createState() =>
      _SpinWheelRewardsSummaryHeaderState();
}

class _SpinWheelRewardsSummaryHeaderState
    extends State<SpinWheelRewardsSummaryHeader> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _syncCountdown();
  }

  @override
  void didUpdateWidget(SpinWheelRewardsSummaryHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spinInfo?.nextSpinInSeconds !=
        widget.spinInfo?.nextSpinInSeconds) {
      _syncCountdown();
    }
  }

  // Anchored off a server-given seconds-remaining offset (not
  // next_spin_at's absolute timestamp) so a wrong device clock can't skew
  // it.
  void _syncCountdown() {
    _timer?.cancel();
    _timer = null;

    final nextSpinInSeconds = widget.spinInfo?.nextSpinInSeconds;
    if (nextSpinInSeconds == null || nextSpinInSeconds <= 0) return;
    final target = DateTime.now().add(Duration(seconds: nextSpinInSeconds));

    _tick(target);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick(target));
  }

  void _tick(DateTime target) {
    final remaining = target.difference(DateTime.now());
    if (remaining.isNegative) {
      _timer?.cancel();
      _timer = null;
      setState(() => _remaining = Duration.zero);
      return;
    }
    setState(() => _remaining = remaining);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Digits only (no "h"/"m"/"s" suffixes) so the countdown never needs its
  // own translation — same colon-separated shape as SpinWheelCountdown's
  // digit tiles in the wheel dialog itself.
  String _formatCountdown(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = context
        .read<CountrySettingsCubit>()
        .getCurrencySymbol();

    final nextSpinInSeconds = widget.spinInfo?.nextSpinInSeconds;
    // Backend kill-switch (settings API `spin_wheel_available`): when off, no
    // entry point to the wheel is shown.
    final spinWheelAvailable =
        SettingsHiveBox.instance.getAppSettings()?.spinWheelAvailable == 1;
    final isCountingDown =
        spinWheelAvailable &&
        nextSpinInSeconds != null &&
        nextSpinInSeconds > 0 &&
        _remaining > Duration.zero;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: ThemeConstants.paddingM,
      ),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: AppDecorations.box(
          color: context.cs.surface,
          borderRadius: AppRadius.r20,
          border: Border.all(
            color: context.cs.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: context.cs.shadow.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingL,
                vertical: ThemeConstants.paddingL,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: AppDecorations.box(
                      color: context.cs.primary,
                      borderRadius: AppRadius.r14,
                    ),
                    child: AppSvgIcon(
                      AssetsConstants.walletIcon,
                      color: context.cs.onPrimary,
                      size: ThemeConstants.iconL,
                      fit: BoxFit.scaleDown,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: ThemeConstants.paddingM,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: ThemeConstants.spaceXS,
                        children: [
                          AppText(
                            context.translate(LanguageLabelKeys.walletRewards),
                            style: context.tt.bodyMedium?.copyWith(
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                          AppText(
                            '$currencySymbol${widget.summary.walletWon.formatPrice(2)}',
                            style: context.tt.headlineMedium?.copyWith(
                              color: context.cs.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (spinWheelAvailable)
                    GestureDetector(
                      // Countdown running: keep the button visible but inert
                      // instead of hiding it, so its position doesn't jump.
                      onTap: isCountingDown
                          ? null
                          : () => SpinWheelDialog.show(
                              context,
                              onRewardWon: (reward) => context
                                  .read<SpinWheelRewardsCubit>()
                                  .prependItem(reward),
                            ),
                      child: Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: ThemeConstants.paddingXL,
                          vertical: ThemeConstants.paddingM,
                        ),
                        decoration: AppDecorations.box(
                          color: isCountingDown
                              ? context.cs.inverseSurface.withValues(alpha: 0.4)
                              : context.cs.inverseSurface,
                          borderRadius: AppRadius.r24,
                        ),
                        child: AppText(
                          context.translate(LanguageLabelKeys.playNow),
                          style: context.tt.headlineLarge?.copyWith(
                            color: context.cs.onInverseSurface.withValues(
                              alpha: isCountingDown ? 0.6 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isCountingDown)
              Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: ThemeConstants.paddingL,
                  vertical: ThemeConstants.paddingM,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.star, AppColors.orange],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: ThemeConstants.spaceS,
                  children: [
                    AppSvgIcon(
                      AssetsConstants.starFillIcon,
                      size: ThemeConstants.iconS,
                      color: AppColors.white,
                    ),
                    AppText(
                      '${context.translate(LanguageLabelKeys.nextRewardIn)} ${_formatCountdown(_remaining)}',
                      style: context.tt.bodyMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppSvgIcon(
                      AssetsConstants.starFillIcon,
                      size: ThemeConstants.iconS,
                      color: AppColors.white,
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
