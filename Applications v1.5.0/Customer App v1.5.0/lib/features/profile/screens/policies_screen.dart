import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/commons/widgets/app_no_internet_widget.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/commons/cubit/country_settings_cubit.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import '../../../commons/cubit/settings_cubit.dart';
import '../../../commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';
import '../widgets/policy_content_skeleton_loader.dart';

enum PoliciesType {
  privacyPolicy,
  termsConditions,
  aboutUs,
  contactUs,
  returnPolicy,
  shippingPolicy,
  returnsAndExchangesPolicy,
}

/// Policy types served by the dedicated settings/policies API instead of
/// the general settings endpoint.
const _dedicatedPolicyTypes = {
  PoliciesType.privacyPolicy,
  PoliciesType.termsConditions,
  PoliciesType.returnPolicy,
  PoliciesType.shippingPolicy,
  PoliciesType.returnsAndExchangesPolicy,
};

String _title(BuildContext context, PoliciesType type) {
  switch (type) {
    case PoliciesType.privacyPolicy:
      return context.translate(LanguageLabelKeys.privacyPolicy);
    case PoliciesType.termsConditions:
      return context.translate(LanguageLabelKeys.termsAndConditions);
    case PoliciesType.aboutUs:
      return context.translate(LanguageLabelKeys.aboutUs);
    case PoliciesType.contactUs:
      return context.translate(LanguageLabelKeys.contactUs);
    case PoliciesType.returnPolicy:
      return context.translate(LanguageLabelKeys.returnPolicy);
    case PoliciesType.shippingPolicy:
      return context.translate(LanguageLabelKeys.shippingPolicy);
    case PoliciesType.returnsAndExchangesPolicy:
      return context.translate(LanguageLabelKeys.cancellationPolicy);
  }
}

String? _contentFromSettings(SettingsLoaded state, PoliciesType type) {
  switch (type) {
    case PoliciesType.aboutUs:
      return state.settings.data?.aboutUs;
    case PoliciesType.contactUs:
      return state.settings.data?.contactUs;
    default:
      return null;
  }
}

String? _contentFromPolicies(CountrySettingsLoaded state, PoliciesType type) {
  switch (type) {
    case PoliciesType.privacyPolicy:
      return state.settings.data?.privacyPolicy;
    case PoliciesType.termsConditions:
      return state.settings.data?.termsConditions;
    case PoliciesType.returnPolicy:
      return state.settings.data?.returnPolicy;
    case PoliciesType.shippingPolicy:
      return state.settings.data?.shippingPolicy;
    case PoliciesType.returnsAndExchangesPolicy:
      return state.settings.data?.cancellationPolicy;
    default:
      return null;
  }
}

Widget _getPolicyEmptyContent(BuildContext context, PoliciesType type) {
  return EmptyStateWidget(
    imagePath: AssetsConstants.noSearchFound,
    title:
        '${_title(context, type)} ${context.translate(LanguageLabelKeys.contentNotAvailable)}',
    subtitle: context.translate(LanguageLabelKeys.contentCurrentlyUnavailable),
  );
}

/// Pull-to-refresh that also works when [child] is shorter than the viewport
/// (empty / error states).
class _PolicyRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;

  const _PolicyRefresh({
    required this.onRefresh,
    required this.child,
    this.controller,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }
}

class PoliciesScreen extends StatelessWidget {
  final PoliciesType type;

  const PoliciesScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    if (_dedicatedPolicyTypes.contains(type)) {
      final cubit = context.read<CountrySettingsCubit>();
      if (cubit.state is CountrySettingsInitial) {
        cubit.loadCountrySettings();
      }
      return _PoliciesDedicatedView(type: type);
    }
    return _PoliciesGeneralView(type: type);
  }
}

class _PoliciesGeneralView extends StatefulWidget {
  final PoliciesType type;

  const _PoliciesGeneralView({required this.type});

  @override
  State<_PoliciesGeneralView> createState() => _PoliciesGeneralViewState();
}

class _PoliciesGeneralViewState extends State<_PoliciesGeneralView> {
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
          context.read<SettingsCubit>().loadSettings();
        }
      },
      builder: (context, connectivityState) {
        return AppScaffold(
          applyBottomInset: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CustomAppBar(
            title: _title(context, widget.type),
            scrollController: _scrollController,
          ),
          // Offline replaces the body only, so the app bar's back button
          // keeps working.
          body: connectivityState is ConnectivityDisconnected
              ? const AppNoInternetView()
              : BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, state) {
                    if (state is SettingsLoading) {
                      return const PolicyContentSkeletonLoader();
                    }

                    if (state is SettingsError) {
                      return _PolicyRefresh(
                        onRefresh: () =>
                            context.read<SettingsCubit>().loadSettings(),
                        child: EmptyStateWidget(
                          imagePath: AssetsConstants.noSearchFound,
                          title: state.message,
                          subtitle: context.translate(
                            LanguageLabelKeys.pullToRefresh,
                          ),
                          onRetry: () =>
                              context.read<SettingsCubit>().loadSettings(),
                        ),
                      );
                    }

                    if (state is SettingsInitial) {
                      context.read<SettingsCubit>().loadSettings();
                      return const PolicyContentSkeletonLoader();
                    }

                    if (state is SettingsLoaded) {
                      final html = _contentFromSettings(state, widget.type);
                      Future<void> refresh() =>
                          context.read<SettingsCubit>().loadSettings();
                      if (html == null || html.isEmpty) {
                        return _PolicyRefresh(
                          onRefresh: refresh,
                          child: _getPolicyEmptyContent(context, widget.type),
                        );
                      }

                      return _PolicyRefresh(
                        onRefresh: refresh,
                        controller: _scrollController,
                        padding: EdgeInsetsDirectional.fromSTEB(
                          ThemeConstants.paddingM,
                          ThemeConstants.paddingS,
                          ThemeConstants.paddingM,
                          ThemeConstants.paddingS + context.bottomSafePadding,
                        ),
                        child: HtmlWidget(html),
                      );
                    }

                    return AppSpacing.shrink;
                  },
                ),
        );
      },
    );
  }
}

class _PoliciesDedicatedView extends StatefulWidget {
  final PoliciesType type;

  const _PoliciesDedicatedView({required this.type});

  @override
  State<_PoliciesDedicatedView> createState() => _PoliciesDedicatedViewState();
}

class _PoliciesDedicatedViewState extends State<_PoliciesDedicatedView> {
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
          context.read<CountrySettingsCubit>().loadCountrySettings(force: true);
        }
      },
      builder: (context, connectivityState) {
        return AppScaffold(
          applyBottomInset: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CustomAppBar(
            title: _title(context, widget.type),
            scrollController: _scrollController,
          ),
          // Offline replaces the body only, so the app bar's back button
          // keeps working.
          body: connectivityState is ConnectivityDisconnected
              ? const AppNoInternetView()
              : BlocBuilder<CountrySettingsCubit, CountrySettingsState>(
                  builder: (context, state) {
                    if (state is CountrySettingsLoading ||
                        state is CountrySettingsInitial) {
                      return const PolicyContentSkeletonLoader();
                    }

                    if (state is CountrySettingsError) {
                      return _PolicyRefresh(
                        onRefresh: () => context
                            .read<CountrySettingsCubit>()
                            .loadCountrySettings(force: true),
                        child: EmptyStateWidget(
                          imagePath: AssetsConstants.noSearchFound,
                          title: state.message,
                          subtitle: context.translate(
                            LanguageLabelKeys.pullToRefresh,
                          ),
                          onRetry: () => context
                              .read<CountrySettingsCubit>()
                              .loadCountrySettings(force: true),
                        ),
                      );
                    }

                    if (state is CountrySettingsLoaded) {
                      final html = _contentFromPolicies(state, widget.type);
                      Future<void> refresh() => context
                          .read<CountrySettingsCubit>()
                          .loadCountrySettings(force: true);
                      if (html == null || html.isEmpty) {
                        return _PolicyRefresh(
                          onRefresh: refresh,
                          child: _getPolicyEmptyContent(context, widget.type),
                        );
                      }

                      return _PolicyRefresh(
                        onRefresh: refresh,
                        controller: _scrollController,
                        padding: EdgeInsetsDirectional.fromSTEB(
                          ThemeConstants.paddingM,
                          ThemeConstants.paddingS,
                          ThemeConstants.paddingM,
                          ThemeConstants.paddingS + context.bottomSafePadding,
                        ),
                        child: HtmlWidget(html),
                      );
                    }

                    return AppSpacing.shrink;
                  },
                ),
        );
      },
    );
  }
}
