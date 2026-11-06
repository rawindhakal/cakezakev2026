import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/utils/pagination_scroll_controller.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import '../cubit/salary_cubit.dart';
import '../models/salary_model.dart';
import '../widgets/salary_list.dart';
import '../../../core/localization/language_label_key.dart';
import '../../../commons/widgets/custom_app_bar.dart';
import '../../../commons/widgets/empty_state_widget.dart';
import '../../../commons/widgets/list_skeleton_loader.dart';
import '../../../utils/extensions/localization_extensions.dart';

/// Screen showing the paginated salary payment history.
class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  late final PaginationScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    context.read<SalaryCubit>().loadSalaries();
    _scrollController = PaginationScrollController(
      onLoadMore: () => context.read<SalaryCubit>().loadMore(),
    );
  }

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
          context.read<SalaryCubit>().loadSalaries();
        }
      },
      builder: (context, connectivityState) {
        final isOffline = connectivityState is ConnectivityDisconnected;
        return AppScaffold(
          applyBottomInset: false,
          appBar: CustomAppBar(
            title: context.translate(LanguageLabelKeys.salary),
            scrollController: _scrollController.controller,
          ),
          // Offline state lives in the body so the app bar — and its back
          // button — stays available on this pushed route.
          body: isOffline
              ? AppNoInternetFullScreen(
                  embedded: true,
                  onRetry: () => context.read<SalaryCubit>().loadSalaries(),
                )
              : BlocConsumer<SalaryCubit, PaginationState<SalaryModel>>(
                  listener: (context, state) {},
                  builder: (context, state) {
                    if (state is PaginationLoading<SalaryModel>) {
                      return const ListSkeletonLoader();
                    }
                    if (state is PaginationError<SalaryModel>) {
                      return EmptyStateWidget(
                        imagePath: AssetsConstants.noSalaryFound,
                        title: state.message,
                        subtitle: context.translate(
                          LanguageLabelKeys.pullDownToRefresh,
                        ),
                        onRetry: () =>
                            context.read<SalaryCubit>().loadSalaries(),
                      );
                    }
                    if (state is PaginationLoaded<SalaryModel>) {
                      return SalaryList(
                        salaries: state.data,
                        total: state.total,
                        isLoadingMore: state.isFetchingMore,
                        hasMore: state.hasMore,
                        scrollController: _scrollController.controller,
                        onRefresh: () =>
                            context.read<SalaryCubit>().loadSalaries(),
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
