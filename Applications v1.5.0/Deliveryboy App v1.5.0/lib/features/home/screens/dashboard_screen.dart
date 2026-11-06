import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/app_snack_bar.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/features/home/cubit/delivery_boy_status_cubit.dart';
import 'package:deliveryboy/features/home/widgets/account_blocked_dialog.dart';
import 'package:deliveryboy/features/home/widgets/dashboard_skeleton_loader.dart';
import 'package:deliveryboy/features/home/widgets/home_header.dart';
import 'package:deliveryboy/features/home/widgets/toggle_status_dialog.dart';
import 'package:deliveryboy/features/home/widgets/home_overview_section.dart';
import 'package:deliveryboy/features/home/widgets/home_performance_section.dart';
import 'package:deliveryboy/features/home/widgets/earnings_trend_card.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/cubit/settings_cubit.dart';
import 'package:deliveryboy/features/profile/cubit/profile_detail_cubit.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/dashboard_cubit.dart';
import '../../../commons/widgets/app_no_internet_widget.dart';
import '../../../commons/cubit/connectivity_cubit.dart';
import '../../../core/services/notification_service.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';

/// Home tab screen showing the delivery boy's dashboard.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Owned here (not inside EarningsTrendCard) because the dashboard's
  // loading state swaps out the whole content tree on every refetch,
  // which would otherwise reset a locally-held selection.
  String _earningsPeriod = LanguageLabelKeys.last7Days;

  @override
  void initState() {
    super.initState();
    context.read<DashboardCubit>().getDashboard(
      trend: trendValueForPeriod(_earningsPeriod),
    );
    context.read<SettingsCubit>().loadSettings();
    context.read<DeliveryBoyStatusCubit>().checkStatus();
    context.read<CountrySettingsCubit>().loadCountrySettings();
    context.read<ProfileDetailCubit>().loadProfile();
    NotificationService.instance.requestPermission();
  }

  Future<void> _onRefresh() async {
    context.read<DashboardCubit>().getDashboard(
      trend: trendValueForPeriod(_earningsPeriod),
    );
    context.read<SettingsCubit>().loadSettings();
    context.read<DeliveryBoyStatusCubit>().checkStatus();
    context.read<CountrySettingsCubit>().loadCountrySettings(force: true);
  }

  void _onEarningsPeriodChanged(String period) {
    setState(() => _earningsPeriod = period);
    context.read<DashboardCubit>().getDashboard(
      trend: trendValueForPeriod(period),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityConnected) _onRefresh();
      },
      builder: (context, connectivityState) {
        if (connectivityState is ConnectivityDisconnected) {
          return AppNoInternetFullScreen(onRetry: _onRefresh);
        }
        return BlocListener<DeliveryBoyStatusCubit, DeliveryBoyStatusState>(
          listener: (context, state) {
            if (state is DeliveryBoyStatusLoaded && state.data.status == 4) {
              showAccountBlockedDialog(context, remark: state.data.remark);
            }
            if (state is DeliveryBoyStatusError) {
              AppSnackBar.show(
                context: context,
                message: state.message,
                type: SnackBarType.error,
              );
            }
          },
          child: Builder(
            builder: (context) => AppScaffold(
              applyBottomInset: false,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              // The header sits outside the dashboard state switch so it stays
              // put while the content below swaps to the skeleton on refetch.
              body: RefreshIndicator(
                onRefresh: _onRefresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    BlocBuilder<DeliveryBoyStatusCubit, DeliveryBoyStatusState>(
                      builder: (context, statusState) {
                        final isOnline =
                            statusState is DeliveryBoyStatusLoaded &&
                            statusState.data.status == 1;
                        return HomeHeader(
                          name: AuthHiveBox.instance.userName,
                          email: AuthHiveBox.instance.userEmail,
                          profileUrl: AuthHiveBox.instance.userProfile,
                          isOnline: isOnline,
                          onToggle: () => showToggleStatusDialog(
                            context,
                            goingOnline: !isOnline,
                          ),
                        );
                      },
                    ),
                    BlocBuilder<DashboardCubit, DashboardState>(
                      builder: (context, state) {
                        if (state is DashboardLoading ||
                            state is DashboardInitial) {
                          return const SliverToBoxAdapter(
                            child: DashboardSkeletonLoader(),
                          );
                        }
                        if (state is DashboardError) {
                          return SliverFillRemaining(
                            // Must stay true: EmptyStateWidget's root is a
                            // LayoutBuilder, and hasScrollBody: false makes the
                            // sliver measure its child's intrinsic height —
                            // which a LayoutBuilder can't provide, throwing
                            // "LayoutBuilder does not support returning
                            // intrinsic dimensions" and then a null-check crash
                            // in the viewport, every time the fetch failed.
                            hasScrollBody: true,
                            child: EmptyStateWidget(
                              imagePath: AssetsConstants.noDataFound,
                              title: state.message,
                              subtitle: context.translate(
                                LanguageLabelKeys.pullDownToRefresh,
                              ),
                              onRetry: _onRefresh,
                            ),
                          );
                        }
                        final d = (state as DashboardLoaded).data;
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              ThemeConstants.paddingL,
                              ThemeConstants.paddingXL,
                              ThemeConstants.paddingL,
                              0,
                            ),
                            child: Column(
                              crossAxisAlignment: .start,
                              children: [
                                HomePerformanceSection(dashboard: d),
                                AppSpacing.h16,
                                HomeOverviewSection(
                                  dashboard: d,
                                  earningsPeriod: _earningsPeriod,
                                  onEarningsPeriodChanged:
                                      _onEarningsPeriodChanged,
                                ),
                                SizedBox(
                                  height: 20 + context.bottomSafePadding,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
