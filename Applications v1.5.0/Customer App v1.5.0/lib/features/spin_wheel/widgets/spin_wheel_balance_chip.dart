import 'package:customer/commons/cubit/country_settings_cubit.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Top-right "wallet rewards" total for the spin dialog: a gold coin showing
/// the currency symbol, sitting on a dark pill with a glowing orange rim that
/// shows the symbol followed by the amount.
///
/// The currency symbol comes from the country-settings API
/// ([CountrySettingsCubit]), never hardcoded, and is read once per build.
/// Hidden for guests and until [amount] has loaded.
class SpinWheelBalanceChip extends StatelessWidget {
  /// Wallet-won total from the rewards API summary (the same figure as the
  /// "Wallet Rewards" card on My Rewards). Null until loaded; the chip
  /// rebuilds itself when it changes.
  final ValueListenable<num?> amount;

  /// Tapping the chip. The dialog uses it to open My Rewards.
  final VoidCallback? onTap;

  const SpinWheelBalanceChip({super.key, required this.amount, this.onTap});

  // Fixed sizes in logical pixels (the chip is small and not screen-scaled).
  static const _coinSize = 34.0;
  static const _pillHeight = 30.0;
  static const _coinOverlap = 8.0; // how far the coin dips into the pill
  static const _width = 92.0;

  @override
  Widget build(BuildContext context) {
    if (!AuthHiveBox.instance.isLoggedIn) return const SizedBox.shrink();
    final symbol = context.read<CountrySettingsCubit>().getCurrencySymbol();
    return ValueListenableBuilder<num?>(
      valueListenable: amount,
      builder: (context, value, _) {
        if (value == null) return const SizedBox.shrink();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: _width,
            height: _coinSize + _pillHeight - _coinOverlap,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                // Warm glow behind the coin and pill.
                Positioned(
                  top: _coinSize * 0.2,
                  child: Container(
                    width: 70,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.spinWheelChipGlow,
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: _pillHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.spinWheelDialogBgTop,
                      borderRadius: BorderRadius.circular(_pillHeight),
                      border: Border.all(
                        color: AppColors.spinWheelChipPillBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Align(
                      alignment: const Alignment(0, 0.55),
                      child: AppText(
                        '$symbol${value.formatPrice(2)}',
                        style: context.tt.titleSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: _Coin(size: _coinSize, symbol: symbol),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Embossed gold coin: outer rim, inner ring and the currency [symbol] (a star
/// if the symbol hasn't loaded yet).
class _Coin extends StatelessWidget {
  final double size;
  final String symbol;

  const _Coin({required this.size, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [
            AppColors.spinWheelCoinRimHi,
            AppColors.spinWheelCoinRimMid,
            AppColors.spinWheelCoinRimLow,
          ],
          stops: [0, 0.65, 1],
        ),
        border: Border.all(color: AppColors.spinWheelCoinBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.spinWheelCoinShadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        width: size * 0.72,
        height: size * 0.72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.spinWheelCoinInnerBorder,
            width: 1,
          ),
        ),
        child: symbol.isEmpty
            ? Icon(
                Icons.star_rounded,
                size: size * 0.42,
                color: AppColors.spinWheelCoinSymbol,
              )
            : AppText(
                symbol,
                style: TextStyle(
                  color: AppColors.spinWheelCoinSymbol,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
      ),
    );
  }
}
