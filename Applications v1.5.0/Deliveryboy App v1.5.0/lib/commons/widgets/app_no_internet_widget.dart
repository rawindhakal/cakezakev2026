import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/services/connectivity_service.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import '../../utils/extensions/context_extensions.dart';
import '../../utils/extensions/localization_extensions.dart';
import '../../utils/extensions/size_extensions.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/commons/widgets/app_button.dart';

class AppNoInternetFullScreen extends StatefulWidget {
  /// Screen-specific reload, run only once connectivity is actually back —
  /// firing it while still offline would just queue failing requests.
  final VoidCallback? onRetry;

  /// Renders without its own [AppScaffold] so the host screen keeps its app
  /// bar (and therefore its back button) while this fills the body. Screens
  /// pushed onto the stack should always use this.
  final bool embedded;

  const AppNoInternetFullScreen({
    super.key,
    this.onRetry,
    this.embedded = false,
  });

  @override
  State<AppNoInternetFullScreen> createState() =>
      _AppNoInternetFullScreenState();
}

class _AppNoInternetFullScreenState extends State<AppNoInternetFullScreen> {
  bool _retrying = false;

  Future<void> _handleRetry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    // Poll the platform rather than waiting on a change event: the event that
    // would have flipped us back online can be missed, so this is the user's
    // only way out without toggling their radio.
    final isConnected = await ConnectivityService().recheck();
    if (!mounted) return;
    setState(() => _retrying = false);
    // Still offline: recheck() emitted nothing, so this screen stays put and
    // the tap reads as a no-op — which is the honest outcome.
    if (isConnected) widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.spaceXXXL,
      ),
      // Center + scroll view keeps the content vertically centred when it fits
      // and scrolls instead of overflowing on short screens or at large text
      // scales.
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSvgIcon(
                AssetsConstants.noInternateFound,
                size: context.widthFraction(0.48),
                color: context.cs.primary,
                useColorMapper: true,
              ),
              AppSpacing.h16,
              AppText(
                // Fallbacks matter here: on a cold start with no network and an
                // empty translation cache, translate() returns the raw key.
                context.translate(
                  LanguageLabelKeys.noInternet,
                  fallback: 'No internet connection',
                ),
                style: context.tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: context.cs.onSurface,
                ),
              ),
              AppSpacing.h8,
              AppText(
                context.translate(
                  LanguageLabelKeys.noInternetSubtitle,
                  fallback: 'Please check your connection and try again.',
                ),
                textAlign: .center,
                style: context.tt.bodyMedium?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
              AppSpacing.h10,
              AppButton(
                label: context.translate(
                  LanguageLabelKeys.retry,
                  fallback: 'Retry',
                ),
                variant: AppButtonVariant.outline,
                width: context.screenWidth * 0.41,
                height: context.screenHeight * 0.054,
                isLoading: _retrying,
                onPressed: _handleRetry,
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) return content;
    return AppScaffold(body: content);
  }
}
