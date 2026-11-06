import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/extensions/context_extensions.dart';
import '../../utils/extensions/localization_extensions.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Body-level no-internet state — no Scaffold of its own, so a screen drops it
/// into the body of its existing scaffold and keeps its app bar (and therefore
/// the back button) usable while offline. Screens with no app bar to preserve
/// (MainScreen's shell, the splash) lay it over their content in a Stack
/// instead.
class AppNoInternetView extends StatefulWidget {
  /// Extra work to run after a successful retry (e.g. refetch this screen's
  /// data). Connectivity is always re-probed regardless of this callback.
  final VoidCallback? onRetry;

  const AppNoInternetView({super.key, this.onRetry});

  @override
  State<AppNoInternetView> createState() => _AppNoInternetViewState();
}

class _AppNoInternetViewState extends State<AppNoInternetView> {
  bool _retrying = false;

  Future<void> _handleRetry() async {
    if (_retrying) return;
    setState(() => _retrying = true);

    // Re-read the platform status. If we're back online the service emits on
    // its stream, the cubit flips to connected, and the host screen swaps this
    // view out on its own — so there's nothing to navigate here.
    await context.read<ConnectivityCubit>().recheck();

    if (!mounted) return;
    setState(() => _retrying = false);
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.spaceXXXL,
      ),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          AppSvgIcon(
            AssetsConstants.noInternateFound,
            size: context.widthFraction(0.48),
            color: context.cs.primary,
            useColorMapper: true,
          ),
          AppSpacing.h16,
          AppText(
            context.translate(LanguageLabelKeys.noInternet),
            style: context.tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w400,
              color: context.cs.onSurface,
            ),
          ),
          AppSpacing.h8,
          AppText(
            context.translate(LanguageLabelKeys.noInternetSubtitle),
            textAlign: .center,
            style: context.tt.bodyMedium?.copyWith(
              color: context.cs.onSurfaceVariant,
            ),
          ),
          AppSpacing.h10,
          AppButton(
            label: context.translate(LanguageLabelKeys.retry),
            onPressed: _handleRetry,
            isLoading: _retrying,
            variant: AppButtonVariant.outline,
            fullWidth: false,
            height: 40,
            contentPadding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingXXL,
              vertical: ThemeConstants.paddingS,
            ),
          ),
        ],
      ),
    );
  }
}
