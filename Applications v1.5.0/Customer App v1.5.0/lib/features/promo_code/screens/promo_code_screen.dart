import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/promo_code/cubit/promo_code_cubit.dart';
import 'package:customer/features/promo_code/cubit/promo_code_validate_cubit.dart';
import 'package:customer/features/promo_code/models/promo_code_model.dart';
import 'package:customer/features/promo_code/widgets/promo_code_input_row.dart';
import 'package:customer/features/promo_code/widgets/promo_code_skeleton_loader.dart';
import 'package:customer/features/promo_code/widgets/promo_code_tile.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

class PromoCodeScreen extends StatefulWidget {
  final String cartTotal;
  final String? latitude;
  final String? longitude;

  /// Checkout's active fulfillment mode — promo eligibility differs between
  /// delivery and pickup, so both list + validate calls are scoped to it.
  final DeliveryType deliveryType;
  const PromoCodeScreen({
    super.key,
    this.cartTotal = '0',
    this.latitude,
    this.longitude,
    this.deliveryType = DeliveryType.delivery,
  });

  @override
  State<PromoCodeScreen> createState() => _PromoCodeScreenState();
}

class _PromoCodeScreenState extends State<PromoCodeScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<PromoCodeCubit>().load(
      amount: widget.cartTotal,
      latitude: widget.latitude,
      longitude: widget.longitude,
      deliveryType: widget.deliveryType,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _apply(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    context.read<PromoCodeValidateCubit>().validate(
      promoCode: trimmed,
      total: widget.cartTotal,
      latitude: widget.latitude,
      longitude: widget.longitude,
      deliveryType: widget.deliveryType,
    );
  }

  void _applyFromList(PromoCodeData item) => _apply(item.promoCode);

  @override
  Widget build(BuildContext context) {
    return BlocListener<PromoCodeValidateCubit, PromoCodeValidateState>(
      listener: (context, state) {
        if (state is PromoCodeValidateSuccess) {
          if (state.data.isApplicable == 1) {
            AppNavigator.pop(context, state.data);
          } else {
            AppSnackBar.show(
              context: context,
              message: state.data.message.isNotEmpty
                  ? state.data.message
                  : context.translate(LanguageLabelKeys.promoCodeNotApplicable),
              type: SnackBarType.error,
            );
          }
        } else if (state is PromoCodeValidateError) {
          AppSnackBar.show(
            context: context,
            message: state.message,
            type: SnackBarType.error,
          );
        }
      },
      child: AppScaffold(
        applyBottomInset: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: CustomAppBar(
          title: context.translate(LanguageLabelKeys.promoCodes),
          scrollController: _scrollController,
        ),
        body: Column(
          spacing: ThemeConstants.spaceL,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ThemeConstants.paddingL,
                ThemeConstants.paddingL,
                ThemeConstants.paddingL,
                0,
              ),
              child: PromoCodeInputRow(
                controller: _controller,
                onApply: _apply,
              ),
            ),
            Expanded(
              child: BlocBuilder<PromoCodeCubit, PromoCodeState>(
                builder: (context, state) {
                  if (state is PromoCodeLoading) {
                    return const PromoCodeSkeletonLoader();
                  }
                  if (state is PromoCodeError) {
                    return EmptyStateWidget(
                      imagePath: AssetsConstants.noCouponFound,
                      title: state.message,
                      subtitle: context.translate(LanguageLabelKeys.tapRetry),
                      onRetry: () => context.read<PromoCodeCubit>().load(
                        amount: widget.cartTotal,
                        latitude: widget.latitude,
                        longitude: widget.longitude,
                        deliveryType: widget.deliveryType,
                      ),
                    );
                  }
                  if (state is PromoCodeLoaded) {
                    Future<void> onRefresh() =>
                        context.read<PromoCodeCubit>().load(
                          amount: widget.cartTotal,
                          latitude: widget.latitude,
                          longitude: widget.longitude,
                          deliveryType: widget.deliveryType,
                        );
                    if (state.items.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: onRefresh,
                        child: ListView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            EmptyStateWidget(
                              imagePath: AssetsConstants.noCouponFound,
                              title: context.translate(
                                LanguageLabelKeys.noPromoCodes,
                              ),
                              subtitle: context.translate(
                                LanguageLabelKeys.noOffersAvailable,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: onRefresh,
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsetsDirectional.fromSTEB(
                          ThemeConstants.paddingL,
                          0,
                          ThemeConstants.paddingL,
                          ThemeConstants.paddingXXL + context.bottomSafePadding,
                        ),
                        itemCount: state.items.length,
                        itemBuilder: (context, index) => PromoCodeTileWidget(
                          item: state.items[index],
                          onApply: () => _applyFromList(state.items[index]),
                        ),
                      ),
                    );
                  }
                  return AppSpacing.shrink;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
