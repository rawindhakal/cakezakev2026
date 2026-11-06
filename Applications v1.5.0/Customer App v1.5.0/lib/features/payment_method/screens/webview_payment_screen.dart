import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/order_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/payment_method/cubit/payment_cubit.dart';
import 'package:customer/features/payment_method/models/payment_form_payload.dart';
import 'package:customer/features/payment_method/models/payment_method_item.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';

class WebViewPaymentArgs {
  const WebViewPaymentArgs({
    required this.url,
    required this.orderId,
    this.orderItemId = '',
    required this.paymentType,
    required this.gateway,
    this.isWalletTopUp = false,
    this.extra,
    this.merchantOrderId,
    this.phonePeToken,
    this.formPayload,
    this.deliveryType = DeliveryType.delivery,
  });

  final String url;
  final String orderId;
  final String orderItemId;
  final String paymentType;
  final PaymentGatewayType gateway;
  final bool isWalletTopUp;
  final Map<String, dynamic>? extra;
  final String? merchantOrderId;
  final String? phonePeToken;

  /// PayU: auto-submitted to its checkout instead of loading [url].
  final PaymentFormPayload? formPayload;

  /// Carried through to order success — see [PaymentArgs.deliveryType].
  final DeliveryType deliveryType;
}

class WebViewPaymentScreen extends StatefulWidget {
  const WebViewPaymentScreen({super.key, required this.args});

  final WebViewPaymentArgs args;

  @override
  State<WebViewPaymentScreen> createState() => _WebViewPaymentScreenState();
}

class _WebViewPaymentScreenState extends State<WebViewPaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _handled = false;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) => setState(() => _isLoading = false),
          onNavigationRequest: _onNavigationRequest,
          onUrlChange: (change) {
            if (change.url != null) _detectStatus(change.url!);
          },
        ),
      );
    _configurePlatform().whenComplete(_loadCheckout);
  }

  /// PayU's bank 3DS pages need third-party cookies, and some banks reject
  /// a User-Agent carrying Android's `; wv` webview marker.
  Future<void> _configurePlatform() async {
    if (widget.args.gateway != PaymentGatewayType.payu) return;
    final platform = _controller.platform;
    if (platform is! AndroidWebViewController) return;
    try {
      final cookies = WebViewCookieManager().platform;
      if (cookies is AndroidWebViewCookieManager) {
        await cookies.setAcceptThirdPartyCookies(platform, true);
      }
      final ua = await _controller.getUserAgent();
      if (ua != null && ua.contains('; wv')) {
        await _controller.setUserAgent(
          ua
              .replaceAll('; wv', '')
              .replaceFirst(RegExp(r'Version/[\d.]+ '), ''),
        );
      }
    } catch (_) {}
  }

  void _loadCheckout() {
    if (!mounted) return;
    final form = widget.args.formPayload;
    if (form != null) {
      // Fields go in exactly as received — backend signed the hash over them.
      _controller.loadHtmlString(
        form.toAutoSubmitHtml(),
        baseUrl: Uri.tryParse(form.action)?.origin,
      );
    } else {
      _controller.loadRequest(Uri.parse(widget.args.url));
    }
  }

  static final _schemeRegex = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*):');
  static const _webSchemes = {'http', 'https', 'about', 'data', 'blob'};

  NavigationDecision _onNavigationRequest(NavigationRequest req) {
    final scheme = _schemeRegex.firstMatch(req.url)?.group(1)?.toLowerCase();
    // upi://, intent://, phonepe://, tez://, paytmmp:// … belong to the OS —
    // loading them in the webview makes every UPI option fail silently.
    if (scheme != null && !_webSchemes.contains(scheme)) {
      _openExternally(req.url);
      return NavigationDecision.prevent;
    }
    _detectStatus(req.url);
    return NavigationDecision.navigate;
  }

  /// Hands an app link to the OS. Android `intent://…#Intent;scheme=x;…;end`
  /// URLs are rebuilt as `x://…` since url_launcher can't fire them as-is,
  /// falling back to `S.browser_fallback_url` when no app takes the link.
  Future<void> _openExternally(String url) async {
    var target = url;
    String? fallback;
    final intentStart = url.indexOf('#Intent;');
    if (url.startsWith('intent://') && intentStart != -1) {
      String? scheme;
      for (final part in url.substring(intentStart + 8).split(';')) {
        if (part.startsWith('scheme=')) scheme = part.substring(7);
        if (part.startsWith('S.browser_fallback_url=')) {
          fallback = Uri.decodeComponent(part.substring(23));
        }
      }
      if (scheme != null) {
        target = '$scheme://${url.substring(9, intentStart)}';
      }
    }
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(target),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (kDebugMode) {
      debugPrint('[WebViewPayment] external $target launched=$launched');
    }
    if (!launched && fallback != null && mounted) {
      _controller.loadRequest(Uri.parse(fallback));
    }
  }

  Map<String, String> _queryParams(String url) =>
      Uri.tryParse(url)?.queryParameters ?? {};

  void _detectStatus(String url) {
    if (_handled) return;
    final params = _queryParams(url);

    if (kDebugMode) {
      debugPrint(
        '[WebViewPayment] gateway=${widget.args.gateway} url=$url params=$params',
      );
    }

    switch (widget.args.gateway) {
      case PaymentGatewayType.phonepe:
        final status = params['status'];
        if (status == null || status.isEmpty) return;
        _handled = true;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handlePhonePe(status),
        );

      case PaymentGatewayType.midtrans:
        final code = params['status_code'];
        if (code == null || code.isEmpty) return;
        _handled = true;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handleMidtrans(code),
        );

      case PaymentGatewayType.cashfree:
      case PaymentGatewayType.dpo:
      case PaymentGatewayType.paytabs:
        // Our own web-payment-status redirect page lands with an empty
        // status first (before it finishes verifying with the gateway) —
        // ignore that hit and wait for the follow-up navigation that
        // carries the real value.
        final status = params['status'];
        if (status == null || status.isEmpty) return;
        _handled = true;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handleGenericStatus(status),
        );

      case PaymentGatewayType.payu:
        // Backend settles the payment, then lands on
        // /web-payment-status?status=success|failed|pending — the
        // /addon/payu/redirect hop before it is ignored.
        if (!(Uri.tryParse(url)?.path.contains('web-payment-status') ??
            false)) {
          return;
        }
        final status = params['status']?.toLowerCase();
        if (status == null || status.isEmpty) return;
        _handled = true;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handlePayU(status),
        );

      case PaymentGatewayType.paypal:
        // Status comes as a query param (?status=success|fail|pending) on
        // the redirect URL — fall back to the old path-segment convention
        // (/success or /fail) for backwards compatibility.
        final segment =
            params['status']?.toLowerCase() ??
            Uri.tryParse(url)?.pathSegments.lastOrNull?.toLowerCase();
        if (segment == null) return;
        if (segment == 'success' || segment == 'fail' || segment == 'pending') {
          _handled = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _handlePayPal(segment),
          );
        }

      default:
        break;
    }
  }

  void _handlePhonePe(String status) {
    if (!mounted) return;
    final cubit = context.read<PaymentCubit>();
    AppNavigator.pop(context);
    switch (status) {
      case 'SUCCESS':
        cubit.onPhonePeSuccess(
          orderId: widget.args.orderId,
          orderItemId: widget.args.orderItemId,
          merchantOrderId: widget.args.merchantOrderId ?? '',
          token: widget.args.phonePeToken ?? '',
          extra: widget.args.extra,
        );
      case 'PENDING':
        // Pending — payment still processing at PhonePe's end, order kept
        // (not deleted) so it can resolve via status check / retry.
        cubit.onWebViewFailed(
          context.translate(LanguageLabelKeys.phonepePaymentPending),
        );
      case 'FAILED':
      case 'ERROR':
        cubit.deleteOrder(widget.args.orderId);
        cubit.onWebViewFailed(
          context.translate(LanguageLabelKeys.phonepePaymentFailed),
        );
      case 'DECLINED':
        cubit.deleteOrder(widget.args.orderId);
        cubit.onWebViewFailed(
          context.translate(LanguageLabelKeys.phonepePaymentDeclined),
        );
      case 'CANCELLED':
        cubit.deleteOrder(widget.args.orderId);
        cubit.onWebViewFailed(
          context.translate(LanguageLabelKeys.phonepePaymentCancelled),
        );
      default:
        cubit.deleteOrder(widget.args.orderId);
        cubit.onWebViewFailed(
          '${context.translate(LanguageLabelKeys.phonepePaymentStatus)} $status.',
        );
    }
  }

  void _handleMidtrans(String statusCode) {
    if (!mounted) return;
    final cubit = context.read<PaymentCubit>();
    switch (statusCode) {
      case '200':
      case '201':
        // Success nav is owned by the BlocListener's PaymentSuccess branch —
        // popping here too races with it and double-pops the stack.
        cubit.onWebViewSuccess(
          widget.args.orderId,
          orderItemId: widget.args.orderItemId,
        );
      case '202':
        AppNavigator.pop(context);
        cubit.deleteOrder(widget.args.orderId);
        cubit.onWebViewFailed(
          context.translate(LanguageLabelKeys.midtransPaymentCancelledByUser),
        );
      default:
        AppNavigator.pop(context);
        cubit.deleteOrder(widget.args.orderId);
        cubit.onWebViewFailed(
          '${context.translate(LanguageLabelKeys.midtransPaymentFailed)} ($statusCode).',
        );
    }
  }

  void _handleGenericStatus(String status) {
    if (!mounted) return;
    final cubit = context.read<PaymentCubit>();
    final isSuccess =
        status == 'success' ||
        status == 'SUCCESS' ||
        status == 'A' ||
        status == 'approved';
    if (isSuccess) {
      // Success nav is owned by the BlocListener's PaymentSuccess branch
      // (pop for wallet top-up, route replace for order checkout) — popping
      // here too double-pops the stack past the intended screen.
      cubit.onWebViewSuccess(
        widget.args.orderId,
        orderItemId: widget.args.orderItemId,
      );
    } else {
      AppNavigator.pop(context);
      cubit.deleteOrder(widget.args.orderId);
      cubit.onWebViewFailed(
        '${context.translate(LanguageLabelKeys.paymentFailedWithStatus)} ($status).',
      );
    }
  }

  void _handlePayU(String status) {
    if (!mounted) return;
    final cubit = context.read<PaymentCubit>();
    switch (status) {
      case 'success':
        // Success nav is owned by the BlocListener's PaymentSuccess branch.
        cubit.onWebViewSuccess(
          widget.args.orderId,
          orderItemId: widget.args.orderItemId,
        );
      case 'pending':
        // Still processing at PayU — order kept, the webhook settles it.
        AppNavigator.pop(context);
        cubit.onWebViewFailed(
          context.translate(LanguageLabelKeys.paymentPendingCheckLater),
        );
      default:
        AppNavigator.pop(context);
        cubit.deleteOrder(widget.args.orderId);
        cubit.onWebViewFailed(
          '${context.translate(LanguageLabelKeys.paymentFailedWithStatus)} ($status).',
        );
    }
  }

  void _handlePayPal(String segment) {
    if (!mounted) return;
    final cubit = context.read<PaymentCubit>();
    AppNavigator.pop(context);
    if (segment.trim().toLowerCase() == 'success') {
      cubit.onWebViewSuccess(
        widget.args.orderId,
        orderItemId: widget.args.orderItemId,
      );
    } else {
      // 'pending' is kept, not deleted — same reasoning as PhonePe PENDING.
      if (segment.trim().toLowerCase() != 'pending') {
        cubit.deleteOrder(widget.args.orderId);
      }
      cubit.onWebViewFailed(
        '${context.translate(LanguageLabelKeys.paypalPaymentFailed)} ($segment).',
      );
    }
  }

  void _onCancel() {
    if (!_handled) {
      _handled = true;
      final cubit = context.read<PaymentCubit>();
      // PayU: a UPI/bank step may already be in flight and its webhook can
      // still settle the order after the webview closes — keep it.
      if (widget.args.gateway != PaymentGatewayType.payu) {
        cubit.deleteOrder(widget.args.orderId);
      }
      cubit.onWebViewFailed(
        context.translate(LanguageLabelKeys.paymentCancelled),
      );
    }
    AppNavigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PaymentCubit, PaymentState>(
      listener: (context, state) {
        if (state is PaymentSuccess) {
          if (widget.args.isWalletTopUp) {
            AppSnackBar.show(
              context: context,
              message: context.translate(LanguageLabelKeys.moneyAddedToWallet),
              type: SnackBarType.success,
            );
            AppNavigator.pop(context, true);
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
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final now = DateTime.now();
          if (_lastBackPress == null ||
              now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
            _lastBackPress = now;
            AppSnackBar.show(
              context: context,
              message: context.translate(
                LanguageLabelKeys.pressBackCancelPayment,
              ),
              type: SnackBarType.info,
            );
          } else {
            _onCancel();
          }
        },
        child: AppScaffold(
          appBar: CustomAppBar(
            title: context.translate(LanguageLabelKeys.completePayment),
            showBackButton: true,
            onBackPressed: () {
              final now = DateTime.now();
              if (_lastBackPress == null ||
                  now.difference(_lastBackPress!) >
                      const Duration(seconds: 2)) {
                _lastBackPress = now;
                AppSnackBar.show(
                  context: context,
                  message: context.translate(
                    LanguageLabelKeys.pressBackCancelPayment,
                  ),
                  type: SnackBarType.info,
                );
              } else {
                _onCancel();
              }
            },
          ),
          body: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading) LoadingWidget(),
            ],
          ),
        ), // Scaffold
      ), // PopScope
    ); // BlocListener
  }
}
