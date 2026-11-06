import 'dart:io';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/menu_card.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/main/screens/main_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:customer/features/chat/models/chat_message.dart';
import 'package:customer/features/chat/services/chat_conversation_resolver.dart';
import 'package:customer/core/localization/cubit/language_cubit.dart';
import 'package:customer/core/localization/models/language_model.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/theme/cubit/theme_cubit.dart';
import 'package:customer/features/profile/widgets/language_sheet.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_banner_card.dart';
import 'package:customer/features/profile/widgets/profile_dialogs.dart';
import 'package:customer/commons/cubit/settings_cubit.dart';
import 'package:customer/commons/cubit/country_settings_cubit.dart';
import 'package:customer/features/profile/screens/policies_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/routes/route_names.dart';
import '../../../utils/extensions/context_extensions.dart';
import '../../../utils/extensions/localization_extensions.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import '../../../commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _scrollController = ScrollController();
  // App bar shadow flag — flips only when leaving/returning to the top, so
  // the app bar isn't rebuilt on every scroll tick.
  final _scrolled = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrolled);
  }

  void _updateScrolled() {
    if (!_scrollController.hasClients) return;
    _scrolled.value = _scrollController.offset > 0;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrolled);
    _scrolled.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No connectivity gate here: this screen only ever renders inside
    // MainScreen's IndexedStack, and MainScreen layers the offline view over
    // the whole shell.
    return AppScaffold(
      applyBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        titleWidget: _ProfileAppBarTitle(
          controller: _scrollController,
          title: context.translate(LanguageLabelKeys.profile),
        ),
        showBackButton: false,
        shadowListenable: _scrolled,
        /* actions: const [_ThemeToggleAction()], */
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, child) => Opacity(
                opacity: 1 - _collapseProgress(_scrollController) * 0.6,
                child: child,
              ),
              child: const _ProfileHeader(),
            ),
          ),
          if (SettingsHiveBox.instance.getAppSettings()?.spinWheelAvailable ==
              1)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  ThemeConstants.paddingL,
                  ThemeConstants.paddingXS,
                  ThemeConstants.paddingL,
                  ThemeConstants.paddingS,
                ),
                child: SpinWheelBannerCard(),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ThemeConstants.paddingL,
                ThemeConstants.paddingXS,
                ThemeConstants.paddingL,
                0,
              ),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  if (AuthHiveBox.instance.isLoggedIn)
                    Builder(
                      builder: (context) {
                        final countrySettingsState = context
                            .watch<CountrySettingsCubit>()
                            .state;
                        final settingsData =
                            countrySettingsState is CountrySettingsLoaded
                            ? countrySettingsState.settings.data
                            : null;
                        final referralFirstOrder =
                            settingsData?.referralCreditFirstOrder ?? 0;
                        final referralReferred =
                            settingsData?.referralCreditReferred ?? 0;
                        final showReferAndEarn =
                            referralFirstOrder != 0 || referralReferred != 0;

                        return MenuCard(
                          title: context.translate(
                            LanguageLabelKeys.personalData,
                          ),
                          items: [
                            MenuItemData(
                              iconPath: AssetsConstants.favouriteIcon,
                              label: context.translate(
                                LanguageLabelKeys.shoppingList,
                              ),
                              onTap: () => AppNavigator.pushNamed(
                                context,
                                RouteNames.favourite,
                              ),
                            ),
                            MenuItemData(
                              iconPath: AssetsConstants.addressIcon,
                              label: context.translate(
                                LanguageLabelKeys.myAddresses,
                              ),
                              onTap: () => AppNavigator.pushNamed(
                                context,
                                RouteNames.addresses,
                              ),
                            ),
                            MenuItemData(
                              iconPath: AssetsConstants.transactionIcon,
                              label: context.translate(
                                LanguageLabelKeys.transactionHistory,
                              ),
                              onTap: () => AppNavigator.pushNamed(
                                context,
                                RouteNames.transactions,
                              ),
                            ),
                            MenuItemData(
                              iconPath: AssetsConstants.walletIcon,
                              label: context.translate(
                                LanguageLabelKeys.walletHistory,
                              ),
                              onTap: () => AppNavigator.pushNamed(
                                context,
                                RouteNames.walletTransactions,
                              ),
                            ),
                            if (showReferAndEarn)
                              MenuItemData(
                                iconPath: AssetsConstants.giftIcon,
                                label: context.translate(
                                  LanguageLabelKeys.referAndEarn,
                                ),
                                onTap: () => AppNavigator.pushNamed(
                                  context,
                                  RouteNames.referEarn,
                                ),
                              ),
                            MenuItemData(
                              iconPath: AssetsConstants.walletIcon,
                              label: context.translate(
                                LanguageLabelKeys.myRewards,
                              ),
                              onTap: () => AppNavigator.pushNamed(
                                context,
                                RouteNames.spinWheelRewards,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  if (AuthHiveBox.instance.isLoggedIn) AppSpacing.h12,
                  BlocBuilder<LanguageCubit, LanguageState>(
                    builder: (context, langState) {
                      String langName;
                      if (langState is LanguageLoaded) {
                        final lang = langState.languages
                            .where(
                              (LanguageJsonData l) =>
                                  l.id == langState.selectedId,
                            )
                            .firstOrNull;
                        final name = lang?.name ?? '';
                        final code =
                            (lang?.code ??
                                    SettingsHiveBox.instance.languageCode)
                                .toUpperCase();
                        langName = name.isNotEmpty ? '$name ($code)' : code;
                      } else {
                        langName = SettingsHiveBox.instance.languageCode
                            .toUpperCase();
                      }
                      return MenuCard(
                        title: context.translate(LanguageLabelKeys.preferences),
                        items: [
                          MenuItemData(
                            iconPath: AssetsConstants.languageIcon,
                            label: context.translate(
                              LanguageLabelKeys.changeLanguage,
                            ),
                            trailing: langName,
                            onTap: () => showLanguageSheet(context),
                          ),
                        ],
                      );
                    },
                  ),
                  AppSpacing.h12,
                  MenuCard(
                    title: context.translate(LanguageLabelKeys.quickAccess),
                    items: [
                      MenuItemData(
                        iconPath: AssetsConstants.notificationIcon,
                        label: context.translate(
                          LanguageLabelKeys.notifications,
                        ),
                        onTap: () => AppNavigator.pushNamed(
                          context,
                          RouteNames.notificationList,
                        ),
                      ),
                      MenuItemData(
                        iconPath: AssetsConstants.shareIcon,
                        label: context.translate(LanguageLabelKeys.shareApp),
                        onTap: () {
                          final settings = context.read<SettingsCubit>().state;
                          if (settings is SettingsLoaded) {
                            final url = Platform.isIOS
                                ? (settings.settings.data?.appstoreUrl ?? '')
                                : (settings.settings.data?.playstoreUrl ?? '');
                            if (url.isNotEmpty) {
                              SharePlus.instance.share(ShareParams(text: url));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  AppSpacing.h12,
                  MenuCard(
                    title: context.translate(LanguageLabelKeys.helpAndSupport),
                    items: [
                      if (AuthHiveBox.instance.isLoggedIn)
                        MenuItemData(
                          iconPath: AssetsConstants.supportChatIcon,
                          label: context.translate(
                            LanguageLabelKeys.chatWithSupport,
                          ),
                          onTap: () async {
                            final conversationId =
                                await resolveAdminConversationId();
                            if (!context.mounted) return;
                            AppNavigator.pushNamed(
                              context,
                              RouteNames.chat,
                              arguments: ChatScreenArgs(
                                chatType: ChatType.adminChat,
                                recipientName: context.translate(
                                  LanguageLabelKeys.chatWithSupport,
                                ),
                                recipientId: AuthHiveBox.instance.userId,
                                conversationId: conversationId,
                                sendLocation: true,
                              ),
                            );
                          },
                        ),
                      MenuItemData(
                        iconPath: AssetsConstants.blogIcon,
                        label: context.translate(LanguageLabelKeys.blog),
                        onTap: () =>
                            AppNavigator.pushNamed(context, RouteNames.blog),
                      ),
                      MenuItemData(
                        iconPath: AssetsConstants.rateIcon,
                        label: context.translate(LanguageLabelKeys.rateUs),
                        onTap: () {
                          final settings = context.read<SettingsCubit>().state;
                          if (settings is SettingsLoaded) {
                            final url = Platform.isIOS
                                ? (settings.settings.data?.appstoreUrl ?? '')
                                : (settings.settings.data?.playstoreUrl ?? '');
                            if (url.isNotEmpty) {
                              launchUrl(
                                Uri.parse(url),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  AppSpacing.h12,
                  MenuCard(
                    title: context.translate(LanguageLabelKeys.helpAndPolicies),
                    items: [
                      MenuItemData(
                        iconPath: AssetsConstants.faqIcon,
                        label: context.translate(LanguageLabelKeys.faq),
                        onTap: () =>
                            AppNavigator.pushNamed(context, RouteNames.faq),
                      ),
                    ],
                    footer: _ExpandableMenuSection(
                      iconPath: AssetsConstants.helpPolicyIcon,
                      label: context.translate(
                        LanguageLabelKeys.helpAndPolicies,
                      ),
                      children: [
                        MenuItemData(
                          iconPath: AssetsConstants.helpPolicyIcon,
                          label: context.translate(LanguageLabelKeys.aboutUs),
                          onTap: () => AppNavigator.pushNamed(
                            context,
                            RouteNames.policies,
                            arguments: PoliciesType.aboutUs,
                          ),
                        ),
                        MenuItemData(
                          iconPath: AssetsConstants.helpPolicyIcon,
                          label: context.translate(LanguageLabelKeys.contactUs),
                          onTap: () => AppNavigator.pushNamed(
                            context,
                            RouteNames.policies,
                            arguments: PoliciesType.contactUs,
                          ),
                        ),
                        MenuItemData(
                          iconPath: AssetsConstants.helpPolicyIcon,
                          label: context.translate(
                            LanguageLabelKeys.privacyPolicy,
                          ),
                          onTap: () => AppNavigator.pushNamed(
                            context,
                            RouteNames.policies,
                            arguments: PoliciesType.privacyPolicy,
                          ),
                        ),
                        MenuItemData(
                          iconPath: AssetsConstants.helpPolicyIcon,
                          label: context.translate(
                            LanguageLabelKeys.termsAndConditions,
                          ),
                          onTap: () => AppNavigator.pushNamed(
                            context,
                            RouteNames.policies,
                            arguments: PoliciesType.termsConditions,
                          ),
                        ),
                        MenuItemData(
                          iconPath: AssetsConstants.helpPolicyIcon,
                          label: context.translate(
                            LanguageLabelKeys.returnPolicy,
                          ),
                          onTap: () => AppNavigator.pushNamed(
                            context,
                            RouteNames.policies,
                            arguments: PoliciesType.returnPolicy,
                          ),
                        ),
                        MenuItemData(
                          iconPath: AssetsConstants.helpPolicyIcon,
                          label: context.translate(
                            LanguageLabelKeys.shippingPolicy,
                          ),
                          onTap: () => AppNavigator.pushNamed(
                            context,
                            RouteNames.policies,
                            arguments: PoliciesType.shippingPolicy,
                          ),
                        ),
                        MenuItemData(
                          iconPath: AssetsConstants.helpPolicyIcon,
                          label: context.translate(
                            LanguageLabelKeys.cancellationPolicy,
                          ),
                          onTap: () => AppNavigator.pushNamed(
                            context,
                            RouteNames.policies,
                            arguments: PoliciesType.returnsAndExchangesPolicy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (AuthHiveBox.instance.isLoggedIn) ...[
                    AppSpacing.h12,
                    MenuCard(
                      title: context.translate(LanguageLabelKeys.account),
                      items: [
                        MenuItemData(
                          iconPath: AssetsConstants.settingsIcon,
                          label: context.translate(LanguageLabelKeys.settings),
                          onTap: () => AppNavigator.pushNamed(
                            context,
                            RouteNames.accountSettings,
                          ),
                        ),
                        MenuItemData(
                          iconPath: AssetsConstants.logoutIcon,
                          label: context.translate(LanguageLabelKeys.logout),
                          onTap: () => showLogoutDialog(context),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 28 + context.bottomSafePadding),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme Toggle Action ────────────────────────────────────────────────────────

class _ThemeToggleAction extends StatefulWidget {
  const _ThemeToggleAction();

  @override
  State<_ThemeToggleAction> createState() => _ThemeToggleActionState();
}

class _ThemeToggleActionState extends State<_ThemeToggleAction> {
  // Shows the flipped icon immediately, ahead of the actual cubit switch —
  // the reveal circle starts growing from this icon's exact center, so it
  // covers the icon instantly and the rotate would otherwise never be seen.
  bool? _previewDark;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, themeState) {
        final cubitIsDark = themeState.themeMode == ThemeMode.dark;
        final isDark = (_previewDark != null && _previewDark != cubitIsDark)
            ? _previewDark!
            : cubitIsDark;
        return Builder(
          builder: (buttonContext) {
            return GestureDetector(
              // Without this, only the icon's actual painted pixels are
              // tappable (GestureDetector defers hit-testing to the child by
              // default) — the surrounding padding looked tappable but
              // wasn't. Opaque makes the whole padded box respond.
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final RenderBox box =
                    buttonContext.findRenderObject() as RenderBox;

                final position = box.localToGlobal(
                  box.size.center(Offset.zero),
                );
                final newTheme = cubitIsDark ? ThemeMode.light : ThemeMode.dark;

                // Wait for the theme switch's heavy tab rebuild to get its
                // first frame painted before starting the rotate. Starting
                // it immediately used to race that rebuild's jank and freeze
                // the icon mid-spin; this keeps the rotate and the reveal
                // circle starting together, both past the jank window.
                await MainScreen.changeTheme(
                  context,
                  newTheme: newTheme,
                  position: position,
                );
                if (!mounted) return;
                setState(() => _previewDark = !cubitIsDark);
              },
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ThemeConstants.paddingS,
                  ThemeConstants.paddingS,
                  ThemeConstants.paddingL,
                  ThemeConstants.paddingS,
                ),
                child: AnimatedSwitcher(
                  // Long enough for the 360° spin to actually read as a
                  // rotation rather than a near-instant pop — 150ms was too
                  // fast to perceive as anything but a fade. Cross-dissolve
                  // via opacity, not scale: scaling from 0 hides the icon
                  // right when it's most tilted (mid-turn), so the rotation
                  // was invisible by the time it grew big enough to see.
                  // Fading keeps it full-size the whole time.
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => RotationTransition(
                    turns: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: AppSvgIcon(
                    isDark
                        ? AssetsConstants.darkThemeIcon
                        : AssetsConstants.lightThemeIcon,
                    key: ValueKey(isDark),
                    size: ThemeConstants.iconM,
                    color: context.cs.onSurface,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Profile Avatar ─────────────────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  final double size;
  final String imageUrl;

  const _ProfileAvatar({required this.size, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final icon = AppSvgIcon(
      AssetsConstants.userIcon,
      size: size * 0.5,
      color: context.cs.onSurfaceVariant,
      fit: BoxFit.scaleDown,
    );
    return Container(
      width: size,
      height: size,
      decoration: AppDecorations.box(
        shape: .circle,
        color: context.cs.surfaceContainerHigh,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? AppNetworkImage(url: imageUrl, placeholder: icon, errorWidget: icon)
          : icon,
    );
  }
}

// ── Collapsing App Bar Title ───────────────────────────────────────────────────

/// Scroll distance (px) over which the header card collapses into the app bar.
const double _kHeaderCollapseStart = 30;
const double _kHeaderCollapseEnd = 110;

double _collapseProgress(ScrollController controller) {
  if (!controller.hasClients) return 0;
  return ((controller.offset - _kHeaderCollapseStart) /
          (_kHeaderCollapseEnd - _kHeaderCollapseStart))
      .clamp(0.0, 1.0);
}

/// App bar title: "Profile" fades out, then avatar, name and email slide in
/// one after another as the scroll progress goes 0 → 1.
class _ProfileAppBarTitle extends StatelessWidget {
  final ScrollController controller;
  final String title;

  const _ProfileAppBarTitle({required this.controller, required this.title});

  static double _step(double p, double begin, double end) =>
      Curves.easeOutCubic.transform(((p - begin) / (end - begin)).clamp(0, 1));

  @override
  Widget build(BuildContext context) {
    // Hive values are read only when the box changes; the per-scroll-tick
    // builder inside just animates with them.
    return ValueListenableBuilder<Box>(
      valueListenable: AuthHiveBox.instance.listenable,
      builder: (context, box, _) {
        final isLoggedIn = AuthHiveBox.instance.isLoggedIn;
        final name = isLoggedIn
            ? AuthHiveBox.instance.userName
            : context.translate(LanguageLabelKeys.guest);
        final email = AuthHiveBox.instance.userEmail;
        final subtitle = email.isNotEmpty
            ? email
            : '${AuthHiveBox.instance.userCountryCode} '
                  '${AuthHiveBox.instance.userMobile}';

        // titleWidget gets titleSpacing 0, so add the same side padding
        // the body cards use to line up with their left edge.
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final p = _collapseProgress(controller);
            final titleT = 1 - _step(p, 0, 0.35);
            final avatarT = _step(p, 0.25, 0.65);
            final nameT = _step(p, 0.4, 0.8);
            final emailT = _step(p, 0.55, 1);

            return Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingL,
              ),
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  if (titleT > 0)
                    Opacity(
                      opacity: titleT,
                      child: Transform.translate(
                        offset: Offset(0, -12 * (1 - titleT)),
                        child: AppText(
                          title,
                          style: context.tt.titleLarge?.copyWith(
                            color: context.cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  if (p > 0)
                    Row(
                      children: [
                        Opacity(
                          opacity: avatarT,
                          child: Transform.scale(
                            scale: 0.6 + 0.4 * avatarT,
                            child: _ProfileAvatar(
                              size: 36,
                              imageUrl: isLoggedIn
                                  ? AuthHiveBox.instance.userProfile
                                  : '',
                            ),
                          ),
                        ),
                        AppSpacing.w10,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: .start,
                            mainAxisAlignment: .center,
                            children: [
                              Opacity(
                                opacity: nameT,
                                child: Transform.translate(
                                  offset: Offset(0, 10 * (1 - nameT)),
                                  child: AppText(
                                    name,
                                    style: context.tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: context.cs.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: .ellipsis,
                                  ),
                                ),
                              ),
                              if (isLoggedIn)
                                Opacity(
                                  opacity: emailT,
                                  child: Transform.translate(
                                    offset: Offset(0, 10 * (1 - emailT)),
                                    child: AppText(
                                      subtitle,
                                      style: context.tt.bodySmall?.copyWith(
                                        fontSize: 11,
                                        color: context.cs.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: .ellipsis,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isLoggedIn) ...[
                          AppSpacing.w8,
                          IgnorePointer(
                            ignoring: emailT < 0.5,
                            child: Opacity(
                              opacity: emailT,
                              child: Transform.scale(
                                scale: 0.6 + 0.4 * emailT,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => AppNavigator.pushNamed(
                                    context,
                                    RouteNames.editProfile,
                                  ),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: AppDecorations.box(
                                      color: context.cs.surfaceContainerHigh,
                                      borderRadius: AppRadius.r8,
                                    ),
                                    alignment: Alignment.center,
                                    child: AppSvgIcon(
                                      AssetsConstants.editIcon,
                                      size: ThemeConstants.iconS,
                                      color: context.cs.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Profile Header ─────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: AuthHiveBox.instance.listenable,
      builder: (context, box, child) {
        final name = AuthHiveBox.instance.userName;
        final email = AuthHiveBox.instance.userEmail;
        final imageUrl = AuthHiveBox.instance.userProfile;
        final mobile = AuthHiveBox.instance.userMobile;
        final countryCode = AuthHiveBox.instance.userCountryCode;
        final isLoggedIn = AuthHiveBox.instance.isLoggedIn;

        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ThemeConstants.paddingL,
            ThemeConstants.paddingL,
            ThemeConstants.paddingL,
            ThemeConstants.paddingS,
          ),
          child: Container(
            decoration: AppDecorations.shadowedCard(
              color: context.cs.surface,
              shadowColor: context.theme.shadowColor.withValues(alpha: 0.06),
              borderRadius: AppRadius.r16,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingL,
              vertical: ThemeConstants.paddingL,
            ),
            child: Row(
              children: [
                _ProfileAvatar(size: 60, imageUrl: isLoggedIn ? imageUrl : ''),
                AppSpacing.w14,
                Expanded(
                  child: isLoggedIn
                      ? Column(
                          crossAxisAlignment: .start,
                          spacing: ThemeConstants.spaceXS,
                          children: [
                            AppText(
                              name,
                              style: context.tt.titleLarge?.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: context.cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                            AppText(
                              email.isNotEmpty ? email : "$countryCode $mobile",
                              style: context.tt.bodySmall?.copyWith(
                                color: context.cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: .start,
                          spacing: ThemeConstants.spaceXS,
                          children: [
                            AppText(
                              context.translate(LanguageLabelKeys.guest),
                              style: context.tt.titleLarge?.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: context.cs.onSurface,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => AppNavigator.pushNamed(
                                context,
                                RouteNames.login,
                              ),
                              child: AppText(
                                '${context.translate(LanguageLabelKeys.login)} / ${context.translate(LanguageLabelKeys.register)}',
                                style: context.tt.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: context.cs.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                if (isLoggedIn) ...[
                  AppSpacing.w8,
                  GestureDetector(
                    onTap: () =>
                        AppNavigator.pushNamed(context, RouteNames.editProfile),
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingM,
                        vertical: ThemeConstants.paddingXS,
                      ),
                      decoration: AppDecorations.box(
                        color: context.cs.surfaceContainerHigh,
                        borderRadius: AppRadius.r8,
                      ),
                      child: Row(
                        mainAxisSize: .min,
                        spacing: ThemeConstants.spaceXS,
                        children: [
                          AppSvgIcon(
                            AssetsConstants.editIcon,
                            size: ThemeConstants.iconXS,
                            color: context.cs.onSurface,
                          ),
                          AppText(
                            context.translate(LanguageLabelKeys.edit),
                            style: context.tt.labelSmall?.copyWith(
                              color: context.cs.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Expandable Menu Section ────────────────────────────────────────────────────

class _ExpandableMenuSection extends StatefulWidget {
  final String iconPath;
  final String label;
  final String? trailing;
  final List<MenuItemData> children;
  final bool useRadioIndicator;

  const _ExpandableMenuSection({
    required this.iconPath,
    required this.label,
    required this.children,
  }) : useRadioIndicator = false,
       trailing = null;

  @override
  State<_ExpandableMenuSection> createState() => _ExpandableMenuSectionState();
}

class _ExpandableMenuSectionState extends State<_ExpandableMenuSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: _expanded ? null : AppRadius.bottom16,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingL,
              vertical: ThemeConstants.paddingM,
            ),
            child: Row(
              spacing: ThemeConstants.spaceL,
              children: [
                AppSvgIcon(
                  widget.iconPath,
                  size: ThemeConstants.iconM,
                  color: context.cs.onSurfaceVariant,
                ),
                Expanded(
                  child: AppText(
                    widget.label,
                    style: context.tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.cs.onSurface,
                    ),
                  ),
                ),
                if (widget.trailing != null) ...[
                  AppText(
                    widget.trailing!,
                    style: context.tt.bodySmall?.copyWith(
                      fontSize: 13,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.w4,
                ],
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: AppSvgIcon(
                    AssetsConstants.arrowDownIcon,
                    color: context.cs.onSurfaceVariant,
                    size: ThemeConstants.iconS,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: List.generate(widget.children.length, (i) {
              final child = widget.children[i];
              return Column(
                children: [
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: context.cs.outlineVariant,
                  ),
                  InkWell(
                    onTap: child.onTap,
                    borderRadius: i == widget.children.length - 1
                        ? AppRadius.bottom16
                        : null,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        ThemeConstants.paddingL,
                        ThemeConstants.paddingM,
                        ThemeConstants.paddingL,
                        ThemeConstants.paddingM,
                      ),
                      child: Row(
                        spacing: ThemeConstants.spaceL,
                        children: [
                          AppSvgIcon(
                            child.iconPath,
                            size: ThemeConstants.iconS,
                            color: context.cs.onSurfaceVariant,
                          ),
                          Expanded(
                            child: AppText(
                              child.label,
                              style: context.tt.bodySmall?.copyWith(
                                color: context.cs.onSurface,
                              ),
                            ),
                          ),
                          if (widget.useRadioIndicator)
                            _RadioDot(selected: child.selected)
                          else
                            Transform.flip(
                              flipX:
                                  Directionality.of(context) ==
                                  TextDirection.rtl,
                              child: AppSvgIcon(
                                AssetsConstants.arrowRightIcon,
                                color: context.cs.onSurfaceVariant,
                                size: ThemeConstants.iconS,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;

  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ThemeConstants.iconS,
      height: ThemeConstants.iconS,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? context.cs.primary : context.cs.onSurfaceVariant,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: ThemeConstants.iconS / 2,
              height: ThemeConstants.iconS / 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.cs.primary,
              ),
            )
          : null,
    );
  }
}
