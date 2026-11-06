import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/payment_method/cubit/payment_methods_cubit.dart';
import 'package:customer/features/payment_method/models/payment_method_item.dart';
import 'package:customer/features/payment_method/widgets/payment_method_tile.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class CheckoutPaymentPickerScreen extends StatefulWidget {
  const CheckoutPaymentPickerScreen({
    super.key,
    required this.selected,
    required this.codAllowed,
  });

  final PaymentMethodItem? selected;
  final bool codAllowed;

  @override
  State<CheckoutPaymentPickerScreen> createState() =>
      _CheckoutPaymentPickerScreenState();
}

class _CheckoutPaymentPickerScreenState
    extends State<CheckoutPaymentPickerScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      applyBottomInset: false,
      appBar: CustomAppBar(
        title: context.translate(LanguageLabelKeys.paymentMethod),
        scrollController: _scrollController,
      ),
      body: BlocBuilder<PaymentMethodsCubit, PaymentMethodsState>(
        builder: (ctx, state) {
          if (state is PaymentMethodsLoading) {
            return const Padding(
              padding: EdgeInsetsDirectional.all(ThemeConstants.spaceXXXL),
              child: LoadingWidget(),
            );
          }
          if (state is PaymentMethodsError) {
            return Padding(
              padding: const EdgeInsetsDirectional.all(
                ThemeConstants.paddingXL,
              ),
              child: Row(
                children: [
                  AppSvgIcon(
                    AssetsConstants.dangerIcon,
                    color: ctx.cs.error,
                    size: ThemeConstants.iconS,
                  ),
                  AppSpacing.w8,
                  Expanded(
                    child: AppText(state.message, style: ctx.tt.bodySmall),
                  ),
                  TextButton(
                    onPressed: ctx
                        .read<PaymentMethodsCubit>()
                        .loadPaymentMethods,
                    child: AppText(context.translate(LanguageLabelKeys.retry)),
                  ),
                ],
              ),
            );
          }
          if (state is PaymentMethodsLoaded) {
            final methods = state.methods
                .where(
                  (m) => m.type != PaymentGatewayType.cod || widget.codAllowed,
                )
                .toList();
            return ListView.separated(
              controller: _scrollController,
              padding: EdgeInsetsDirectional.fromSTEB(
                ThemeConstants.paddingXL,
                ThemeConstants.paddingL,
                ThemeConstants.paddingXL,
                ThemeConstants.paddingXL + ctx.bottomSafePadding,
              ),
              itemCount: methods.length,
              separatorBuilder: (_, _) => AppSpacing.h8,
              itemBuilder: (_, i) {
                final method = methods[i];
                return PaymentMethodTile(
                  method: method,
                  isSelected: widget.selected?.type == method.type,
                  onTap: () => AppNavigator.pop(context, method),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
