import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/commons/cubit/country_settings_cubit.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ReferEarnScreen extends StatelessWidget {
  const ReferEarnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CountrySettingsCubit>();
    if (cubit.state is CountrySettingsInitial) {
      cubit.loadCountrySettings();
    }
    return const _ReferEarnView();
  }
}

class _ReferEarnView extends StatefulWidget {
  const _ReferEarnView();

  @override
  State<_ReferEarnView> createState() => _ReferEarnViewState();
}

class _ReferEarnViewState extends State<_ReferEarnView>
    with SingleTickerProviderStateMixin {
  bool _isSharing = false;
  bool _entranceStarted = false;
  final _scrollController = ScrollController();
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _scrollController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Animation<double> _fade(int index, int total) {
    final start = index / (total + 1);
    final end = start + 2 / (total + 1);
    return CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end.clamp(0, 1), curve: Curves.easeOut),
    );
  }

  Widget _staggered(int index, int total, Widget child) {
    final fade = _fade(index, total);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: fade.drive(
          Tween(begin: const Offset(0, 0.08), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final referralCode = AuthHiveBox.instance.referralCode;

    return AppScaffold(
      applyBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: context.translate(LanguageLabelKeys.referAndEarn),
        scrollController: _scrollController,
      ),
      body: BlocBuilder<CountrySettingsCubit, CountrySettingsState>(
        builder: (context, state) {
          if (state is CountrySettingsLoading ||
              state is CountrySettingsInitial) {
            return const LoadingWidget();
          }

          if (!_entranceStarted) {
            _entranceStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _entranceController.forward();
            });
          }

          final data = state is CountrySettingsLoaded
              ? state.settings.data
              : null;
          final currency = data?.currency ?? '';
          final youEarnValue = data?.referralCreditFirstOrder ?? 0;
          final friendEarnsValue = data?.referralCreditReferred ?? 0;
          final bonus = youEarnValue.toString();

          const total = 4;

          return SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsetsDirectional.fromSTEB(
              ThemeConstants.paddingL,
              ThemeConstants.paddingXL,
              ThemeConstants.paddingL,
              ThemeConstants.paddingL + context.bottomSafePadding,
            ),
            child: Column(
              crossAxisAlignment: .start,
              spacing: ThemeConstants.spaceXXL,
              children: [
                _staggered(
                  0,
                  total,
                  _HeroCard(bonus: bonus, currency: currency),
                ),
                _staggered(
                  1,
                  total,
                  _ReferralCodeCard(
                    referralCode: referralCode,
                    onCopy: () => _copyCode(context, referralCode),
                    onShare: () => _shareCode(context, referralCode),
                  ),
                ),
                _staggered(
                  2,
                  total,
                  _RewardsBreakdownCard(
                    currency: currency,
                    minOrderAmount: data?.referralMinOrderAmount?.toString(),
                    youEarn: youEarnValue > 0 ? youEarnValue.toString() : null,
                    friendEarns: friendEarnsValue > 0
                        ? friendEarnsValue.toString()
                        : null,
                  ),
                ),
                _staggered(
                  3,
                  total,
                  _HowItWorksCard(
                    youEarns: youEarnValue > 0,
                    friendEarns: friendEarnsValue > 0,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _copyCode(BuildContext context, String code) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    AppSnackBar.show(
      context: context,
      message: context.translate(LanguageLabelKeys.referralCodeCopied),
      type: SnackBarType.success,
    );
  }

  Future<void> _shareCode(BuildContext context, String code) async {
    if (code.isEmpty || _isSharing) return;
    _isSharing = true;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              '${context.translate(LanguageLabelKeys.joinAndGetExclusiveRewards)}: $code',
        ),
      );
    } finally {
      _isSharing = false;
    }
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────
class _HeroCard extends StatefulWidget {
  final String bonus;
  final String currency;
  const _HeroCard({required this.bonus, required this.currency});

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);
  late final Animation<double> _pulse = Tween(
    begin: 0.94,
    end: 1.08,
  ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.cs.primary;
    final onPrimary = context.cs.onPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingXL,
        vertical: ThemeConstants.paddingXXL,
      ),
      decoration: AppDecorations.box(
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.r16,
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 64,
              height: 64,
              decoration: AppDecorations.box(
                color: onPrimary.withValues(alpha: 0.2),
                shape: .circle,
              ),
              padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
              child: AppSvgIcon(
                AssetsConstants.giftIcon,
                size: ThemeConstants.iconL,
                color: onPrimary,
              ),
            ),
          ),
          AppSpacing.h14,
          AppText(
            context.translate(LanguageLabelKeys.inviteFriendsAndEarn),
            style: context.tt.headlineSmall?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: onPrimary,
            ),
          ),
          AppSpacing.h6,
          AppText(
            '${context.translate(LanguageLabelKeys.shareCodeEarnBonus)} ${widget.currency}${widget.bonus}\n${context.translate(LanguageLabelKeys.forEverySuccessfulReferral)}',
            textAlign: .center,
            style: context.tt.bodySmall?.copyWith(
              color: onPrimary.withValues(alpha: 0.88),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rewards breakdown card ──────────────────────────────────────────────────────
class _RewardsBreakdownCard extends StatelessWidget {
  final String currency;
  final String? minOrderAmount;
  final String? youEarn;
  final String? friendEarns;

  const _RewardsBreakdownCard({
    required this.currency,
    required this.minOrderAmount,
    required this.youEarn,
    required this.friendEarns,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, String)>[
      if (minOrderAmount != null)
        (
          context.translate(LanguageLabelKeys.minOrder),
          '$currency$minOrderAmount',
        ),
      if (youEarn != null)
        (context.translate(LanguageLabelKeys.youEarn), '$currency$youEarn'),
      if (friendEarns != null)
        (
          context.translate(LanguageLabelKeys.friendEarns),
          '$currency$friendEarns',
        ),
    ];

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.r12,
        border: Border.all(color: context.cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceM,
        children: [
          AppText(
            context.translate(LanguageLabelKeys.rewardDetails),
            style: context.tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.cs.onSurface,
            ),
          ),
          Row(
            children: List.generate(tiles.length, (i) {
              final (label, value) = tiles[i];
              final isLast = i == tiles.length - 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: isLast ? 0 : ThemeConstants.paddingS,
                  ),
                  child: _StatTile(label: label, value: value),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingS,
        vertical: ThemeConstants.paddingL,
      ),
      decoration: AppDecorations.box(
        color: context.cs.surfaceContainerHigh,
        borderRadius: AppRadius.r12,
      ),
      child: Column(
        mainAxisSize: .min,
        spacing: ThemeConstants.spaceXS,
        children: [
          AppText(
            value,
            textAlign: .center,
            maxLines: 1,
            overflow: .ellipsis,
            style: context.tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.cs.primary,
            ),
          ),
          AppText(
            label,
            textAlign: .center,
            maxLines: 1,
            overflow: .ellipsis,
            style: context.tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: context.cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Referral code card ────────────────────────────────────────────────────────
class _ReferralCodeCard extends StatelessWidget {
  final String referralCode;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _ReferralCodeCard({
    required this.referralCode,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.cs.primary;

    return Container(
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.r12,
        border: Border.all(color: context.cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          AppText(
            context.translate(LanguageLabelKeys.yourReferralCode),
            style: context.tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.cs.onSurfaceVariant,
            ),
          ),
          AppSpacing.h12,
          Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingL,
              vertical: ThemeConstants.paddingM,
            ),
            decoration: AppDecorations.box(
              color: primary.withValues(alpha: 0.06),
              borderRadius: AppRadius.r10,
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppText(
                    referralCode.isEmpty ? '—' : referralCode,
                    style: context.tt.headlineSmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: primary,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                _BouncyTap(
                  onTap: onCopy,
                  child: Container(
                    padding: const EdgeInsetsDirectional.all(
                      ThemeConstants.paddingS,
                    ),
                    decoration: AppDecorations.box(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.r8,
                    ),
                    child: AppSvgIcon(
                      AssetsConstants.copyIcon,
                      size: ThemeConstants.iconS,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.h14,
          _BouncyTap(
            child: AppButton(
              label: context.translate(LanguageLabelKeys.shareCode),
              onPressed: onShare,
              height: 46,
              prefixIcon: AppSvgIcon(
                AssetsConstants.shareIcon,
                size: ThemeConstants.iconL,
                color: context.cs.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── How it works card ─────────────────────────────────────────────────────────
class _HowItWorksCard extends StatelessWidget {
  final bool youEarns;
  final bool friendEarns;

  const _HowItWorksCard({required this.youEarns, required this.friendEarns});

  @override
  Widget build(BuildContext context) {
    final primary = context.cs.primary;

    final bonusStep = youEarns && friendEarns
        ? (
            AssetsConstants.walletIcon,
            context.translate(LanguageLabelKeys.youAndYourFriendEarnBonus),
            context.translate(LanguageLabelKeys.youAndYourFriendEarnBonusDesc),
          )
        : youEarns
        ? (
            AssetsConstants.walletIcon,
            context.translate(LanguageLabelKeys.youEarnBonus),
            context.translate(LanguageLabelKeys.youEarnBonusDesc),
          )
        : friendEarns
        ? (
            AssetsConstants.walletIcon,
            context.translate(LanguageLabelKeys.yourFriendEarnsBonus),
            context.translate(LanguageLabelKeys.yourFriendEarnsBonusDesc),
          )
        : null;

    final steps = [
      (
        AssetsConstants.shareIcon,
        context.translate(LanguageLabelKeys.shareYourCode),
        context.translate(LanguageLabelKeys.shareYourCodeDesc),
      ),
      (
        AssetsConstants.userIcon,
        context.translate(LanguageLabelKeys.friendRegisters),
        context.translate(LanguageLabelKeys.friendRegistersDesc),
      ),
      (
        AssetsConstants.orderIcon,
        context.translate(LanguageLabelKeys.friendPlacesOrder),
        context.translate(LanguageLabelKeys.friendPlacesOrderDesc),
      ),
      ?bonusStep,
    ];

    return Container(
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.r12,
        border: Border.all(color: context.cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          AppText(
            context.translate(LanguageLabelKeys.howItWorks),
            style: context.tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.cs.onSurface,
            ),
          ),
          AppSpacing.h16,
          ...List.generate(steps.length, (i) {
            final (icon, title, desc) = steps[i];
            final isLast = i == steps.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: .start,
                spacing: ThemeConstants.spaceL,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: AppDecorations.box(
                          color: primary.withValues(alpha: 0.1),
                          shape: .circle,
                        ),
                        child: AppSvgIcon(
                          icon,
                          size: ThemeConstants.iconL,
                          color: primary,
                          fit: BoxFit.scaleDown,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            color: primary.withValues(alpha: 0.2),
                            margin: const EdgeInsetsDirectional.symmetric(
                              vertical: ThemeConstants.paddingXS,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        top: ThemeConstants.paddingXS,
                        bottom: isLast ? 0 : ThemeConstants.paddingXL,
                      ),
                      child: Column(
                        crossAxisAlignment: .start,
                        spacing: ThemeConstants.spaceXXS,
                        children: [
                          AppText(
                            title,
                            style: context.tt.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.cs.onSurface,
                            ),
                          ),
                          AppText(
                            desc,
                            style: context.tt.bodySmall?.copyWith(
                              color: context.cs.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Bouncy tap feedback ──────────────────────────────────────────────────────
class _BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _BouncyTap({required this.child, this.onTap});

  @override
  State<_BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<_BouncyTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.0,
    upperBound: 0.15,
  );
  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: 0.88,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
