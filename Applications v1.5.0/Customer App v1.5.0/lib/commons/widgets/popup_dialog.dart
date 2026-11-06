import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/commons/models/enums/popup_action_type.dart';
import 'package:customer/commons/utils/url_launcher_helper.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/routes/category_redirect_args.dart';
import 'package:customer/core/routes/product_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:customer/features/products/screens/product_screen.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/constants/theme_constants.dart';

class PopupDialog extends StatelessWidget {
  final AppSettingsData settings;

  const PopupDialog({super.key, required this.settings});

  static bool _shownThisSession = false;

  /// Returns a future that resolves once the popup (if shown) is dismissed,
  /// or immediately if it wasn't shown — lets callers chain another dialog
  /// (e.g. the spin wheel) after this one closes instead of stacking both.
  static Future<void> maybeShow(BuildContext context) {
    final settings = SettingsHiveBox.instance.getAppSettings();
    if (settings == null) return Future.value();
    if (settings.popupEnabled != '1') return Future.value();

    final alwaysShow = settings.popupAlwaysShowHome == '1';
    if (!alwaysShow && _shownThisSession) return Future.value();

    _shownThisSession = true;
    return showDialog(
      context: context,
      barrierColor: context.cs.scrim.withValues(alpha: 0.54),
      builder: (_) => PopupDialog(settings: settings),
    );
  }

  void _handleTap(BuildContext context) {
    AppNavigator.pop(context);
    final type = PopupActionType.fromRaw(settings.popupType);
    final typeId = settings.popupTypeId ?? '';
    final url = settings.popupUrl ?? '';

    switch (type) {
      case PopupActionType.product:
        final id = int.tryParse(typeId);
        if (id != null) {
          AppNavigator.pushNamed(
            context,
            RouteNames.productDetail,
            arguments: ProductDetailArgs(productId: id),
          );
        }
        break;
      case PopupActionType.category:
        if (settings.popupHasChild ?? true) {
          AppNavigator.pushNamed(
            context,
            RouteNames.categories,
            arguments: CategoryRedirectArgs(
              categoryId: typeId,
              hasChild: settings.popupHasChild ?? true,
            ),
          );
        } else {
          AppNavigator.push(
            context,
            BlocProvider(
              create: (_) => ProductCubit(),
              child: ProductScreen(
                title: settings.popupTypeName?.isNotEmpty == true
                    ? settings.popupTypeName!
                    : context.translate(LanguageLabelKeys.category),
                categoryId: typeId,
              ),
            ),
          );
        }
        break;
      case PopupActionType.popupUrl:
        if (url.isNotEmpty) openExternalUrl(url);
        break;
      case PopupActionType.brand:
        AppNavigator.push(
          context,
          BlocProvider(
            create: (_) => ProductCubit(),
            child: ProductScreen(
              title: settings.popupTypeName?.isNotEmpty == true
                  ? settings.popupTypeName!
                  : context.translate(LanguageLabelKeys.brand),
              brandId: typeId,
            ),
          ),
        );
        break;
      case PopupActionType.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: ThemeConstants.spaceXXXL,
        vertical: ThemeConstants.paddingXXL,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Image
          GestureDetector(
            onTap: () => _handleTap(context),
            child: ClipRRect(
              borderRadius: AppRadius.r16,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  width: double.infinity,
                  // Capped so the popup reads as a promo card, not a
                  // full-screen takeover — source images vary in aspect
                  // ratio and would otherwise stretch the dialog to fit.
                  height: context.heightFraction(0.42),
                  color: Colors.white,
                  child: AppNetworkImage(
                    url: settings.popupImage ?? '',
                    fit: BoxFit.contain,
                    errorWidget: const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),

          // Close button — top-end corner overlapping image
          PositionedDirectional(
            top: -14,
            end: -14,
            child: GestureDetector(
              onTap: () => AppNavigator.pop(context),
              child: Container(
                width: 30,
                height: 30,
                padding: EdgeInsetsDirectional.all(ThemeConstants.paddingXS),
                decoration: AppDecorations.box(
                  color: context.cs.primary,
                  shape: .circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.cs.scrim.withValues(alpha: 0.25),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: AppSvgIcon(
                  AssetsConstants.closeIcon,
                  color: context.cs.onInverseSurface,
                  size: ThemeConstants.iconL,
                  fit: BoxFit.scaleDown,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
