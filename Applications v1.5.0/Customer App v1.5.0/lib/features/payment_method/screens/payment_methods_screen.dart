import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_no_internet_widget.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/order_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/features/payment_method/cubit/payment_cubit.dart';
import 'package:customer/features/payment_method/cubit/payment_methods_cubit.dart';
import 'package:customer/features/payment_method/models/payment_args.dart';
import 'package:customer/features/payment_method/models/payment_method_item.dart';
import 'package:customer/features/payment_method/models/payment_methods_model.dart';
import 'package:customer/features/payment_method/screens/webview_payment_screen.dart';
import 'package:customer/features/payment_method/widgets/paystack_launcher_mixin.dart';
import 'package:customer/features/payment_method/widgets/payment_method_tile.dart';
import 'package:customer/features/payment_method/widgets/payment_methods_skeleton_loader.dart';
import 'package:customer/features/payment_method/widgets/razorpay_launcher_mixin.dart';
import 'package:customer/features/payment_method/widgets/stripe_launcher_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

export 'package:customer/features/payment_method/models/payment_args.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key, required this.args});

  final PaymentArgs args;

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen>
    with RazorpayLauncherMixin, StripeLauncherMixin, PaystackLauncherMixin {
  PaymentMethodItem? _selectedMethod;
  // Cashfree's WebViewPaymentScreen already pops itself + this screen via
  // the awaited push below on PaymentSuccess — tracked so the PaymentSuccess
  // branch doesn't pop a second time for cashfree only. Other gateways pop
  // themselves before emitting, so this screen's own pop stays their only one.
  PaymentGatewayType? _pendingGateway;
  final _scrollController = ScrollController();

  @override
  PaymentArgs get launcherArgs => widget.args;

  @override
  void initState() {
    super.initState();
    // Route already loads via BlocProvider(create: (_) => PaymentMethodsCubit()..loadPaymentMethods()).
    initRazorpay();
  }

  @override
  void dispose() {
    disposeRazorpay();
    _scrollController.dispose();
    super.dispose();
  }

  void _pay() {
    if (_selectedMethod == null) return;
    context.read<PaymentCubit>().initiatePayment(
      orderId: widget.args.orderId,
      orderItemId: widget.args.orderItemId,
      method: _selectedMethod!,
      extra: widget.args.extra,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PaymentCubit, PaymentState>(
      listener: _onPaymentStateChanged,
      child: AppScaffold(
        appBar: CustomAppBar(
          title: context.translate(LanguageLabelKeys.paymentMethod),
          showBackButton: true,
          scrollController: _scrollController,
        ),
        bottomNavigationBar: BlocBuilder<ConnectivityCubit, ConnectivityState>(
          builder: (context, connectivity) {
            if (connectivity is ConnectivityDisconnected) {
              return const SizedBox.shrink();
            }
            return BlocBuilder<PaymentMethodsCubit, PaymentMethodsState>(
              builder: (context, state) {
                if (state is! PaymentMethodsLoaded) {
                  return const SizedBox.shrink();
                }
                final methods = widget.args.isWalletTopUp
                    ? state.methods
                          .where((m) => m.type != PaymentGatewayType.cod)
                          .toList()
                    : state.methods;
                if (methods.isEmpty) return const SizedBox.shrink();
                return _BottomBar(
                  amount: widget.args.amount,
                  currency: widget.args.currency,
                  enabled: _selectedMethod != null,
                  isProcessing:
                      context.watch<PaymentCubit>().state is PaymentProcessing,
                  isWalletTopUp: widget.args.isWalletTopUp,
                  onPay: _pay,
                );
              },
            );
          },
        ),
        body: BlocConsumer<ConnectivityCubit, ConnectivityState>(
          listener: (context, connectivity) {
            if (connectivity is ConnectivityConnected) {
              context.read<PaymentMethodsCubit>().loadPaymentMethods();
            }
          },
          builder: (context, connectivity) {
            if (connectivity is ConnectivityDisconnected) {
              // View, not FullScreen — this already sits inside an AppScaffold
              // whose app bar carries the back button.
              return const AppNoInternetView();
            }
            return BlocBuilder<PaymentMethodsCubit, PaymentMethodsState>(
              builder: (context, state) {
                if (state is PaymentMethodsLoading) {
                  return const PaymentMethodsSkeletonLoader();
                }
                if (state is PaymentMethodsError) {
                  return EmptyStateWidget(
                    imagePath: AssetsConstants.noWalletFound,
                    title: state.message,
                    subtitle: context.translate(
                      LanguageLabelKeys.pullToRefresh,
                    ),
                    onRetry: context
                        .read<PaymentMethodsCubit>()
                        .loadPaymentMethods,
                  );
                }
                if (state is PaymentMethodsLoaded) {
                  final methods = widget.args.isWalletTopUp
                      ? state.methods
                            .where((m) => m.type != PaymentGatewayType.cod)
                            .toList()
                      : state.methods;
                  if (methods.isEmpty) {
                    return EmptyStateWidget(
                      imagePath: AssetsConstants.noWalletFound,
                      title: context.translate(
                        LanguageLabelKeys.noPaymentMethods,
                      ),
                      subtitle: context.translate(
                        LanguageLabelKeys.noPaymentMethodsSubtitle,
                      ),
                    );
                  }
                  return _Body(
                    methods: methods,
                    methodsData: state.data,
                    selectedMethod: _selectedMethod,
                    scrollController: _scrollController,
                    onMethodSelected: (m) =>
                        setState(() => _selectedMethod = m),
                  );
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _onPaymentStateChanged(
    BuildContext context,
    PaymentState state,
  ) async {
    final methodsState = context.read<PaymentMethodsCubit>().state;
    final methodsData = methodsState is PaymentMethodsLoaded
        ? methodsState.data
        : null;

    if (state is PaymentWebViewReady) {
      // Share this screen's PaymentCubit with the webview route instead of
      // letting it create its own — otherwise a status callback that pops
      // the webview screen before its async work finishes (PhonePe/Midtrans/
      // etc.) emits into an instance nobody is listening to anymore.
      final paymentCubit = context.read<PaymentCubit>();
      _pendingGateway = state.gateway;
      final result = await AppNavigator.push(
        context,
        BlocProvider.value(
          value: paymentCubit,
          child: WebViewPaymentScreen(
            args: WebViewPaymentArgs(
              url: state.url,
              orderId: state.orderId,
              orderItemId: state.orderItemId,
              paymentType: state.paymentType,
              gateway: state.gateway,
              isWalletTopUp: widget.args.isWalletTopUp,
              extra: state.extra,
              merchantOrderId: state.merchantOrderId,
              phonePeToken: state.phonePeToken,
              formPayload: state.formPayload,
              deliveryType: widget.args.deliveryType,
            ),
          ),
        ),
      );
      // WebViewPaymentScreen pops with true on success — propagate up
      if (result == true && mounted) {
        if (widget.args.isWalletTopUp) {
          AppNavigator.pop(this.context, true);
        }
        // Order flow: WebViewPaymentScreen already calls popUntil(main)
      }
    } else if (state is PaymentSdkReady) {
      switch (state.gateway) {
        case PaymentGatewayType.razorpay:
          launchRazorpay(state, methodsData);
        case PaymentGatewayType.stripe:
          launchStripe(state, methodsData);
        case PaymentGatewayType.paystack:
          launchPaystack(state, methodsData);
        default:
          break;
      }
    } else if (state is PaymentSuccess) {
      if (widget.args.isWalletTopUp) {
        AppSnackBar.show(
          context: context,
          message: context.translate(LanguageLabelKeys.moneyAddedToWallet),
          type: SnackBarType.success,
        );
        // Cashfree/Midtrans/PayU: WebViewPaymentScreen's own listener pops
        // itself, and the awaited push above propagates that pop up to
        // here already — an extra pop here would remove the Wallet screen
        // too. Other gateways pop themselves before this state even
        // arrives, so they still need this pop to close this screen.
        if (_pendingGateway != PaymentGatewayType.cashfree &&
            _pendingGateway != PaymentGatewayType.midtrans &&
            _pendingGateway != PaymentGatewayType.payu) {
          AppNavigator.pop(context, true);
        }
      } else {
        AppNavigator.pushNamedAndRemoveUntilRoute(
          context,
          RouteNames.orderSuccess,
          RouteNames.main,
          arguments: OrderSuccessArgs(
            orderId: state.orderId,
            orderItemId: state.orderItemId,
            deliveryType: widget.args.deliveryType,
          ),
        );
      }
    } else if (state is PaymentError) {
      AppSnackBar.show(
        context: context,
        message: state.message,
        type: SnackBarType.error,
      );
    }
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.methods,
    required this.methodsData,
    required this.selectedMethod,
    required this.scrollController,
    required this.onMethodSelected,
  });

  final List<PaymentMethodItem> methods;
  final PaymentMethodsData methodsData;
  final PaymentMethodItem? selectedMethod;
  final ScrollController scrollController;
  final ValueChanged<PaymentMethodItem> onMethodSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
      itemCount: methods.length,
      separatorBuilder: (_, _) => AppSpacing.h10,
      itemBuilder: (_, i) {
        final method = methods[i];
        return PaymentMethodTile(
          method: method,
          isSelected: selectedMethod?.type == method.type,
          onTap: () => onMethodSelected(method),
        );
      },
    );
  }
}

// ── Bottom pay bar ────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.amount,
    required this.currency,
    required this.enabled,
    required this.isProcessing,
    required this.isWalletTopUp,
    required this.onPay,
  });

  final double amount;
  final String currency;
  final bool enabled;
  final bool isProcessing;
  final bool isWalletTopUp;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingL,
        MediaQuery.paddingOf(context).bottom + ThemeConstants.paddingL,
      ),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.top16,
        boxShadow: [
          BoxShadow(
            color: context.cs.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: .min,
        spacing: ThemeConstants.spaceM,
        children: [
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              AppText(
                isWalletTopUp
                    ? context.translate(LanguageLabelKeys.addToWallet)
                    : context.translate(LanguageLabelKeys.totalAmount),
                style: context.tt.bodyMedium?.copyWith(
                  color: context.cs.onSurface,
                ),
              ),
              AppText(
                '$currency${amount.formatPrice(2)}',
                style: context.tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: isProcessing
                  ? context.translate(LanguageLabelKeys.processing)
                  : isWalletTopUp
                  ? context.translate(LanguageLabelKeys.addMoney)
                  : context.translate(LanguageLabelKeys.payNow),
              onPressed: enabled && !isProcessing ? onPay : null,
              isLoading: isProcessing,
            ),
          ),
        ],
      ),
    );
  }
}
