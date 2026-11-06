import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/cubit/language_cubit.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/cubit/dashboard_cubit.dart';
import '../widgets/earnings_skeleton_loader.dart';
import '../widgets/earnings_summary_card.dart';
import '../widgets/earnings_quick_access_section.dart';
import '../../../commons/widgets/custom_app_bar.dart';
import '../../../commons/widgets/empty_state_widget.dart';
import '../../../utils/extensions/context_extensions.dart';
import '../../../utils/extensions/localization_extensions.dart';

/// Screen summarizing total/today earnings, wallet stats, and quick access to salary/cash/fund transfer.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final DashboardCubit _cubit = DashboardCubit();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _cubit.getDashboard();
  }

  @override
  void dispose() {
    _cubit.close();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocListener<LanguageCubit, LanguageState>(
        listenWhen: (previous, current) =>
            previous is LanguageLoaded &&
            current is LanguageLoaded &&
            previous.selectedId != current.selectedId,
        listener: (context, state) => _cubit.getDashboard(),
        child: BlocConsumer<ConnectivityCubit, ConnectivityState>(
          listener: (context, state) {
            if (state is ConnectivityConnected) {
              _cubit.getDashboard();
            }
          },
          builder: (context, connectivityState) {
            final isOffline = connectivityState is ConnectivityDisconnected;
            return AppScaffold(
              applyBottomInset: false,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: CustomAppBar(
                title: context.translate(LanguageLabelKeys.earnings),
                showBackButton: false,
                scrollController: _scrollController,
              ),
              // Offline state lives in the body so the tab keeps its app bar and
              // the bottom navigation bar stays reachable.
              body: isOffline
                  ? AppNoInternetFullScreen(
                      embedded: true,
                      onRetry: () => _cubit.getDashboard(),
                    )
                  : BlocConsumer<DashboardCubit, DashboardState>(
                      listener: (context, state) {},
                      builder: (context, state) {
                        if (state is DashboardLoading ||
                            state is DashboardInitial) {
                          return const EarningsSkeletonLoader();
                        }
                        if (state is DashboardError) {
                          return EmptyStateWidget(
                            imagePath: AssetsConstants.noWalletFound,
                            title: state.message,
                            subtitle: context.translate(
                              LanguageLabelKeys.pullDownToRefresh,
                            ),
                            onRetry: () => _cubit.getDashboard(),
                          );
                        }
                        if (state is DashboardLoaded) {
                          final currencySymbol = context
                              .read<CountrySettingsCubit>()
                              .getCurrencySymbol();
                          final data = state.data.data;
                          return RefreshIndicator(
                            color: context.cs.primary,
                            onRefresh: () => _cubit.getDashboard(),
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsetsDirectional.only(
                                bottom:
                                    ThemeConstants.spaceXXXL +
                                    context.bottomSafePadding,
                              ),
                              child: Column(
                                crossAxisAlignment: .start,
                                spacing: ThemeConstants.spaceXL,
                                children: [
                                  EarningsSummaryCard(
                                    totalEarning:
                                        data?.wallet?.totalEarned ?? 0,
                                    todayEarning: data?.today?.earnings ?? 0,
                                    currencySymbol: currencySymbol,
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.symmetric(
                                          horizontal: ThemeConstants.paddingL,
                                        ),
                                    child: Column(
                                      crossAxisAlignment: .start,
                                      spacing: ThemeConstants.spaceXL,
                                      children: [
                                        EarningsQuickAccessSection(
                                          wallet: data?.wallet,
                                          salary: data?.salary,
                                          cash: data?.cash,
                                          settlementHistory:
                                              data?.cash?.totalSettled ?? 0,
                                          currencySymbol: currencySymbol,
                                          onWalletTap: () =>
                                              AppNavigator.pushNamed(
                                                context,
                                                RouteNames.wallet,
                                              ),
                                          onSalaryTap: () =>
                                              AppNavigator.pushNamed(
                                                context,
                                                RouteNames.salary,
                                              ),
                                          onCashCollectionTap: () =>
                                              AppNavigator.pushNamed(
                                                context,
                                                RouteNames.cashCollection,
                                              ),
                                          onFundTransferTap: () =>
                                              AppNavigator.pushNamed(
                                                context,
                                                RouteNames.settlementHistory,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
            );
          },
        ),
      ),
    );
  }
}
