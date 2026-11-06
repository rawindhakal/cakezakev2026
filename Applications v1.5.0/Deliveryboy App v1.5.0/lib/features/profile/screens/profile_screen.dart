import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/custom_app_bar.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/cubit/theme_cubit.dart';
import 'package:deliveryboy/features/main/screens/main_screen.dart';
import 'package:deliveryboy/features/profile/cubit/profile_detail_cubit.dart';
import 'package:deliveryboy/features/profile/widgets/profile_account_section.dart';
import 'package:deliveryboy/features/profile/widgets/profile_collapsing_title.dart';
import 'package:deliveryboy/features/profile/widgets/profile_header.dart';
import 'package:deliveryboy/features/profile/widgets/profile_preferences_section.dart';
import 'package:deliveryboy/features/profile/widgets/profile_quick_help_section.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Main profile tab showing header, preferences, help, and account sections.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityConnected) {
          context.read<ProfileDetailCubit>().loadProfile();
        }
      },
      builder: (context, connectivityState) {
        final isOffline = connectivityState is ConnectivityDisconnected;
        return AppScaffold(
          applyBottomInset: false,
          appBar: CustomAppBar(
            titleWidget: ProfileCollapsingTitle(
              controller: _scrollController,
              title: context.translate(LanguageLabelKeys.myProfile),
            ),
            showBackButton: false,
            scrollController: _scrollController,
            /* actions: const [_ThemeToggleAction()], */
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          // App bar stays mounted while offline so the screen keeps its
          // identity instead of being replaced wholesale.
          body: isOffline
              ? AppNoInternetFullScreen(
                  embedded: true,
                  onRetry: () =>
                      context.read<ProfileDetailCubit>().loadProfile(),
                )
              : CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: AnimatedBuilder(
                        animation: _scrollController,
                        builder: (context, child) => Opacity(
                          opacity:
                              1 - profileCollapseProgress(_scrollController) * 0.6,
                          child: child,
                        ),
                        child: const ProfileHeader(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          ThemeConstants.paddingL,
                          ThemeConstants.paddingXS,
                          ThemeConstants.paddingL,
                          context.bottomSafePadding,
                        ),
                        child: Column(
                          crossAxisAlignment: .start,
                          children: const [
                            ProfilePreferencesSection(),
                            ProfileQuickHelpSection(),
                            ProfileAccountSection(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
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
        final isDark = (_previewDark != null && _previewDark != cubitIsDark) ? _previewDark! : cubitIsDark;
        return Builder(
          builder: (buttonContext) {
            return GestureDetector(
              // Without this, only the icon's actual painted pixels are
              // tappable (GestureDetector defers hit-testing to the child by
              // default) — the surrounding padding looked tappable but
              // wasn't. Opaque makes the whole padded box respond.
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final RenderBox box = buttonContext.findRenderObject() as RenderBox;

                final position = box.localToGlobal(box.size.center(Offset.zero));
                final newTheme = cubitIsDark ? ThemeMode.light : ThemeMode.dark;

                // Wait for the theme switch's heavy tab rebuild to get its
                // first frame painted before starting the rotate. Starting
                // it immediately used to race that rebuild's jank and freeze
                // the icon mid-spin; this keeps the rotate and the reveal
                // circle starting together, both past the jank window.
                await MainScreen.changeTheme(context, newTheme: newTheme, position: position);
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
                    isDark ? AssetsConstants.darkThemeIcon : AssetsConstants.lightThemeIcon,
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
