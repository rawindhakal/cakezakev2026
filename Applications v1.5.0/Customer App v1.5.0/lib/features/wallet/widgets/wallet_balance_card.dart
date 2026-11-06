import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/commons/cubit/country_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class WalletBalanceCard extends StatelessWidget {
  final VoidCallback onAddMoney;

  const WalletBalanceCard({super.key, required this.onAddMoney});

  @override
  Widget build(BuildContext context) {
    final currencySymbol = context
        .read<CountrySettingsCubit>()
        .getCurrencySymbol();

    return ValueListenableBuilder<Box>(
      valueListenable: AuthHiveBox.instance.listenable,
      builder: (context, box, child) {
        final balance =
            double.tryParse(AuthHiveBox.instance.userBalance) ?? 0.0;
        return Container(
          width: double.infinity,
          margin: const EdgeInsetsDirectional.fromSTEB(
            ThemeConstants.paddingL,
            ThemeConstants.paddingL,
            ThemeConstants.paddingL,
            ThemeConstants.paddingS,
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingL,
            vertical: ThemeConstants.paddingL,
          ),
          decoration: AppDecorations.box(
            color: context.cs.surface,
            borderRadius: AppRadius.r20,
            border: Border.all(
              color: context.cs.outlineVariant.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: context.cs.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: .center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: AppDecorations.box(
                  color: context.cs.primary,
                  borderRadius: AppRadius.r14,
                ),
                child: AppSvgIcon(
                  AssetsConstants.walletIcon,
                  color: context.cs.onPrimary,
                  size: ThemeConstants.iconL,
                  fit: BoxFit.scaleDown,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: ThemeConstants.paddingM,
                  ),
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    spacing: ThemeConstants.spaceXS,
                    children: [
                      AppText(
                        context.translate(LanguageLabelKeys.availableBalance),
                        style: context.tt.bodyMedium?.copyWith(
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                      AppText(
                        '$currencySymbol${balance.formatPrice(2)}',
                        style: context.tt.headlineMedium?.copyWith(
                          color: context.cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: onAddMoney,
                child: Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: ThemeConstants.paddingXL,
                    vertical: ThemeConstants.paddingM,
                  ),
                  decoration: AppDecorations.box(
                    color: context.cs.inverseSurface,
                    borderRadius: AppRadius.r24,
                  ),
                  child: AppText(
                    context.translate(LanguageLabelKeys.addMoney),
                    style: context.tt.headlineLarge?.copyWith(
                      color: context.cs.onInverseSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
