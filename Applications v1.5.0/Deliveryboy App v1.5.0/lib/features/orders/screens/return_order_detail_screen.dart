import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/custom_app_bar.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/features/orders/widgets/order_skeletons.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/orders/widgets/return_order_detail_body.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/return_order_detail_cubit.dart';
import '../models/return_order_model.dart';

/// Detail screen for a single return request. Route args are either the
/// return request ID (order-card tap — fetched via API) or an already-loaded
/// [ReturnRequestData] (QR scan — resolved by the scan API, so it's shown
/// straight away with no second round trip).
class ReturnOrderDetailScreen extends StatefulWidget {
  const ReturnOrderDetailScreen({super.key});

  @override
  State<ReturnOrderDetailScreen> createState() =>
      _ReturnOrderDetailScreenState();
}

class _ReturnOrderDetailScreenState extends State<ReturnOrderDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return BlocProvider(
      create: (_) {
        final cubit = ReturnOrderDetailCubit();
        if (args is ReturnRequestData) {
          cubit.loadLocal(args);
        } else {
          cubit.loadDetail(args?.toString() ?? '');
        }
        return cubit;
      },
      child: const _ReturnDetailView(),
    );
  }
}

class _ReturnDetailView extends StatelessWidget {
  const _ReturnDetailView();

  @override
  Widget build(BuildContext context) {
    // No full-screen offline gate here: the error branch below already renders
    // an app bar + Retry with ApiException's "no internet connection" message.
    // This listener just adds recovery without a manual tap.
    return BlocListener<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityConnected) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is ReturnRequestData) return;
          context.read<ReturnOrderDetailCubit>().loadDetail(
            args?.toString() ?? '',
          );
        }
      },
      child: AppScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        applyBottomInset: false,
        body: BlocBuilder<ReturnOrderDetailCubit, ReturnOrderDetailState>(
          builder: (context, state) {
            if (state is ReturnOrderDetailLoading) {
              return AppScaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                appBar: CustomAppBar(
                  title: context.translate(LanguageLabelKeys.returnDetail),
                  showBackButton: true,
                ),
                body: const OrderDetailSkeleton(showItemsCard: false),
              );
            }
            if (state is ReturnOrderDetailError) {
              return AppScaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                appBar: CustomAppBar(
                  title: context.translate(LanguageLabelKeys.returnDetail),
                  showBackButton: true,
                ),
                body: EmptyStateWidget(
                  imagePath: AssetsConstants.noOrderFound,
                  title: state.message,
                  subtitle: context.translate(
                    LanguageLabelKeys.pullDownToRefresh,
                  ),
                  onRetry: () {
                    final id =
                        ModalRoute.of(
                          context,
                        )?.settings.arguments?.toString() ??
                        '';
                    context.read<ReturnOrderDetailCubit>().loadDetail(id);
                  },
                ),
              );
            }
            if (state is ReturnOrderDetailLoaded) {
              return ReturnOrderDetailBody(detail: state.data);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
