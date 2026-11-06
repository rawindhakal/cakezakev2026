import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import '../../../commons/cubit/country_settings_cubit.dart';
import '../../../commons/widgets/custom_app_bar.dart';

enum PoliciesType { privacyPolicy, termsConditions }

/// Displays the privacy policy or terms and conditions HTML content.
class PoliciesScreen extends StatefulWidget {
  final PoliciesType type;

  const PoliciesScreen({super.key, required this.type});

  @override
  State<PoliciesScreen> createState() => _PoliciesScreenState();
}

class _PoliciesScreenState extends State<PoliciesScreen> {
  final _scrollController = ScrollController();
  PoliciesType get type => widget.type;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _title(BuildContext context) => switch (type) {
    PoliciesType.privacyPolicy => context.translate(
      LanguageLabelKeys.privacyPolicy,
    ),
    PoliciesType.termsConditions => context.translate(
      LanguageLabelKeys.termsAndConditions,
    ),
  };

  String? _content(CountrySettingsLoaded state) => switch (type) {
    PoliciesType.privacyPolicy => state.settings.data?.privacyPolicy,
    PoliciesType.termsConditions => state.settings.data?.termsConditions,
  };

  Widget _getPolicyEmptyContent(BuildContext context, PoliciesType type) {
    switch (type) {
      case PoliciesType.privacyPolicy:
        return EmptyStateWidget(
          imagePath: AssetsConstants.noDataFound,
          title: context.translate(LanguageLabelKeys.privacyPolicyNotAvailable),
          subtitle: context.translate(LanguageLabelKeys.privacyPolicyNotFound),
        );
      case PoliciesType.termsConditions:
        return EmptyStateWidget(
          imagePath: AssetsConstants.noDataFound,
          title: context.translate(LanguageLabelKeys.termsNotAvailable),
          subtitle: context.translate(LanguageLabelKeys.termsNotFound),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityConnected) {
          context.read<CountrySettingsCubit>().loadCountrySettings();
        }
      },
      builder: (context, connectivityState) {
        final isOffline = connectivityState is ConnectivityDisconnected;
        return AppScaffold(
          applyBottomInset: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CustomAppBar(
            title: _title(context),
            scrollController: _scrollController,
          ),
          // Offline state lives in the body so the app bar — and its back
          // button — stays available on this pushed route.
          body: isOffline
              ? AppNoInternetFullScreen(
                  embedded: true,
                  onRetry: () => context
                      .read<CountrySettingsCubit>()
                      .loadCountrySettings(force: true),
                )
              : BlocBuilder<CountrySettingsCubit, CountrySettingsState>(
                  builder: (context, state) {
                    if (state is CountrySettingsLoading) {
                      return const ShimmerParagraph(lines: 12);
                    }

                    if (state is CountrySettingsError) {
                      return EmptyStateWidget(
                        imagePath: AssetsConstants.noDataFound,
                        title: state.message,
                        subtitle: context.translate(
                          LanguageLabelKeys.pullDownToRefresh,
                        ),
                        onRetry: () => context
                            .read<CountrySettingsCubit>()
                            .loadCountrySettings(force: true),
                      );
                    }

                    if (state is CountrySettingsInitial) {
                      context
                          .read<CountrySettingsCubit>()
                          .loadCountrySettings();
                      return const ShimmerParagraph(lines: 12);
                    }

                    if (state is CountrySettingsLoaded) {
                      final html = _content(state);
                      if (html == null || html.isEmpty) {
                        return RefreshIndicator(
                          color: context.cs.primary,
                          onRefresh: () => context
                              .read<CountrySettingsCubit>()
                              .loadCountrySettings(force: true),
                          child: LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: _getPolicyEmptyContent(context, type),
                              ),
                            ),
                          ),
                        );
                      }

                      return RefreshIndicator(
                        color: context.cs.primary,
                        onRefresh: () => context
                            .read<CountrySettingsCubit>()
                            .loadCountrySettings(force: true),
                        child: LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsetsDirectional.fromSTEB(
                              ThemeConstants.paddingM,
                              ThemeConstants.paddingS,
                              ThemeConstants.paddingM,
                              ThemeConstants.paddingS +
                                  context.bottomSafePadding,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: HtmlWidget(html),
                            ),
                          ),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
        );
      },
    );
  }
}
